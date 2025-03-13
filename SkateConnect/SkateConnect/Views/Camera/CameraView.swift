//
//  CameraView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import os

import AVFoundation
import SwiftUI

struct CameraView: View {
    let log = OSLog(subsystem: "SkateConnect", category: "Camera")

    @StateObject var cameraViewModel = CameraViewModel()
    
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var uploadManager: UploadManager
    
    @State private var isRetrying = false
    @State private var isShowingAlert = false

    let zoomSensitivity: CGFloat = 0.3

    var body: some View {
        ZStack {
            if cameraViewModel.session.isRunning {
                GeometryReader { geo in

                CameraPreview(session: cameraViewModel.session)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                let maxZoom: CGFloat = 5.0 // Maximum zoom level
                                let minZoom: CGFloat = 1.0 // Minimum zoom level

                                // Adjust zoom sensitivity
                                let adjustedZoom = val - 1.0 // Gesture starts at 1.0, so normalize
                                let newZoomFactor = min(max(minZoom, cameraViewModel.zoomFactor + adjustedZoom * zoomSensitivity), maxZoom)

                                cameraViewModel.zoom(factor: newZoomFactor) // Zoom to the calculated factor
                            }
                            .onEnded { _ in
                                cameraViewModel.zoomFactor = cameraViewModel.zoomFactor
                            }
                    )
                }
                .ignoresSafeArea()
            }
            
            // Loading indicator when camera is starting
            if cameraViewModel.hasCameraAccess && !cameraViewModel.cameraReady  {
                VStack {
                    ProgressView("Initializing camera...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .onAppear {
                            cameraViewModel.checkPermissionsAndSetup()
                        }
                }
            }

            VStack {
                Spacer()

                if !uploadManager.isUploading {
                    if cameraViewModel.hasCameraAccess && cameraViewModel.cameraReady {
                        HStack {
                            Spacer()

                            if cameraViewModel.isRecording {
                                Text("REC")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(5)
                                    .background(Circle().fill(Color.black.opacity(0.7)))
                                    .padding()
                            }

                            // Record Button
                            Button(action: {
                                if cameraViewModel.isRecording {
                                    cameraViewModel.stopRecording()
                                } else {
                                    cameraViewModel.startRecording()
                                }
                            }) {
                                Circle()
                                    .strokeBorder(cameraViewModel.isRecording ? Color.red : Color.white, lineWidth: 5)
                                    .frame(width: 70, height: 70)
                            }
                            .padding()
                            .disabled(!cameraViewModel.cameraReady)

                            Spacer()
                        }
                    }
                }
            }

            if !cameraViewModel.hasCameraAccess {
                VStack {
                    Text("Camera is disabled. Please enable it in your phone's settings.")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                        .transition(.opacity)

                    Button(action: {
                        // Open app settings
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }) {
                        Text("Open Settings")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }

            if cameraViewModel.isVideoRecorded && !cameraViewModel.isRecording {
                VStack {
                    Spacer()

                    if uploadManager.isUploading {
                        ProgressView("Uploading...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .padding()
                    } else {
                        HStack {
                            Spacer()

                            Button(action: {
                                cameraViewModel.showingPreview = true
                            }) {
                                Text("✂️ Edit")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Capsule().fill(Color.blue))
                            }
                            .padding(.trailing)
                        }
                        .padding(.bottom, 40)
                    }
                }
                .sheet(isPresented: $cameraViewModel.showingPreview) {
                    VideoEditorView(
                        url: uploadManager.videoURL,
                        cameraViewModel: cameraViewModel
                    )
                    .environmentObject(uploadManager)
                }
            }
        }
        .onDisappear {
            let group = DispatchGroup()
            group.enter()
            cameraViewModel.stopSession {
                group.leave()
            }
            // Optional: group.wait() if needed
        }
        .onReceive(NotificationCenter.default.publisher(for: .didFinishUpload)) {_ in 
            isShowingAlert = true
        }
        .alert("Video posted.", isPresented: $isShowingAlert) {
            Button("Ok", role: .cancel) {
                if let videoURL = self.uploadManager.videoURL {
                    navigation.completeUpload(videoURL: videoURL)
                    dismiss()
                }
            }
        }
    }
}
