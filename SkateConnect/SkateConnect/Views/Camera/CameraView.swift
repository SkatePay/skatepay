//
//  CameraView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import AVFoundation
import SwiftUI

struct CameraView: View {
    @StateObject var cameraViewModel = CameraViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigation: Navigation

    // Sensitivity factor to control zoom speed
    let zoomSensitivity: CGFloat = 0.3

    var body: some View {
        ZStack {
            if cameraViewModel.hasCameraAccess {
                CameraPreview(session: cameraViewModel.session)
                    .ignoresSafeArea()
                    .onAppear {
                        cameraViewModel.checkPermissionsAndSetup()
                    }
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
                                // Save the zoom factor after the gesture ends
                                cameraViewModel.zoomFactor = cameraViewModel.zoomFactor
                            }
                    )
            }

            VStack {
                Spacer()

                if !cameraViewModel.isUploading {
                    if cameraViewModel.hasCameraAccess {
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

                    if cameraViewModel.isUploading {
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
                    VideoEditorView(url: cameraViewModel.videoURL, cameraViewModel: cameraViewModel)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    cameraViewModel.showZoomHint = false
                }
            }

            guard let channelId = navigation.channelId else {
                print("Error: Channel ID is nil.")
                return
            }

            cameraViewModel.channelId = channelId
        }
        .alert("Video posted.", isPresented: $cameraViewModel.showingAlert) {
            Button("Ok", role: .cancel) {
                if let videoURL = self.cameraViewModel.videoURL {
                    navigation.completeUpload(videoURL: videoURL)
                    dismiss()
                }
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Ensure preview layer resizes dynamically
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: CameraPreview
        var previewLayer: AVCaptureVideoPreviewLayer?

        init(_ parent: CameraPreview) {
            self.parent = parent
        }
    }
}
