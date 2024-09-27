//
//  CameraView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import AVFoundation
import ConnectFramework
import SwiftUI
import AWSS3
import AWSCognitoIdentityProvider

struct CameraView: View {
    @StateObject var cameraViewModel = CameraViewModel()
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var navigation = NavigationManager.shared

    var body: some View {
        ZStack {
            CameraPreview(session: cameraViewModel.session)
                .onAppear {
                    cameraViewModel.checkPermissionsAndSetup()
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let maxZoom: CGFloat = 5.0
                            let zoomFactor = min(max(1.0, cameraViewModel.zoomFactor + val - 1), maxZoom)
                            cameraViewModel.zoom(factor: zoomFactor)
                        }
                )
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.leading)
                    
                    if cameraViewModel.showZoomHint {
                        Text("Pinch to zoom")
                            .font(.caption)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                Spacer()

                if (!cameraViewModel.isUploading) {
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

            if !cameraViewModel.hasCameraAccess {
                Text("Camera access denied. Please enable in settings.")
                    .foregroundColor(.white)
                    .background(Color.red)
                    .transition(.opacity)
            }

            // Preview or Upload Button (Appears after recording stops)
            if cameraViewModel.isVideoRecorded {
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
                    VideoPreviewView(url: cameraViewModel.videoURL, cameraViewModel: cameraViewModel)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    cameraViewModel.showZoomHint = false
                }
            }
        }
        .alert("Video posted.", isPresented: $cameraViewModel.showingAlert) {
            Button("Ok", role: .cancel) {
                if let videoURL = self.cameraViewModel.videoURL {
                    navigation.completeUpload(videoURL: videoURL)
                    presentationMode.wrappedValue.dismiss()
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
class CameraViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var isRecording = false
    @Published var isVideoRecorded = false
    @Published var showingPreview = false
    @Published var showZoomHint = true
    @Published var hasCameraAccess = true
    @Published var isUploading = false
    @Published var showingAlert = false
    
    var zoomFactor: CGFloat = 1.0
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    var videoURL: URL?

    // MARK: - Check Permissions and Setup
    func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.configureSession()
                    }
                } else {
                    print("Camera access denied.")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted.")
        @unknown default:
            print("Unknown camera permission status.")
        }
    }

    // MARK: - Configure Camera Session
    func configureSession() {
        session.beginConfiguration()

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("Unable to access camera.")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        } catch {
            print("Error: Unable to add video input.")
        }

        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                print("Error: Unable to add audio input.")
            }
        }

        // Add video output
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        // Start the session
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }

    // MARK: - Start Recording
    func startRecording() {
        let outputDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".mov"
        videoURL = outputDirectory.appendingPathComponent(fileName)

        guard let url = videoURL else { return }

        videoOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    // MARK: - Stop Recording
    func stopRecording() {
        videoOutput.stopRecording()
        isRecording = false
    }

    // MARK: - Delegate Method for Saving File
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
            return
        }

        print("Video saved at: \(outputFileURL)")
        isVideoRecorded = true
        videoURL = outputFileURL
    }

    // MARK: - Zoom Functionality
    func zoom(factor: CGFloat) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Error: Unable to zoom.")
        }
    }
    
    
    // MARK: - Simulate Video Upload
    func uploadFiles(imageURL: URL) async throws {
        Task {
            try await uploadImage(imageURL: imageURL)
            try await uploadVideo()
        }
        
        showingPreview = false
        isUploading = false
        showingAlert = true
    }
    
    // Upload image to S3
    func uploadImage(imageURL: URL) async throws {
        let serviceHandler = try await S3ServiceHandler(
            region: "us-west-2",
            accessKeyId: Keys.S3_ACCESS_KEY_ID,
            secretAccessKey: Keys.S3_SECRET_ACCESS_KEY
        )
        
        let objName = imageURL.lastPathComponent
        try await serviceHandler.uploadFile(
            bucket: Constants.S3_BUCKET,
            key: objName,
            fileUrl: imageURL
        )
        print("Image uploaded to S3: \(objName)")
    }
    
    func uploadVideo() async throws {
        let serviceHandler = try await S3ServiceHandler(
            region: "us-west-2",
            accessKeyId: Keys.S3_ACCESS_KEY_ID,
            secretAccessKey: Keys.S3_SECRET_ACCESS_KEY
        )
        
        guard let videoURL = videoURL else { return }
        print("Uploading video from URL: \(videoURL)")
        
        let objName = videoURL.lastPathComponent
        
        try await serviceHandler.uploadFile(
            bucket: Constants.S3_BUCKET,
            key: objName,
            fileUrl: videoURL
        )

        // Simulate upload...
        isVideoRecorded = false
    }
    
    func requestTemporaryToken(bucket: String) async throws -> String {
        let url = URL(string: "\(Constants.API_URL_SKATEPARK)/token?bucket=\(bucket)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return (json as! [String: String])["token"]!
    }
}
