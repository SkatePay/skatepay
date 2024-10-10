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
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var navigation = Navigation.shared
    
    // Sensitivity factor to control zoom speed
    let zoomSensitivity: CGFloat = 0.3
    
    var body: some View {
        ZStack {
            CameraPreview(session: cameraViewModel.session)
                .onAppear {
                    cameraViewModel.checkPermissionsAndSetup()
                }
            // Add gesture to the entire ZStack to ensure it works immediately
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
                        .onEnded { val in
                            // Save the zoom factor after the gesture ends
                            cameraViewModel.zoomFactor = cameraViewModel.zoomFactor
                        }
                )
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
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
            
            if !cameraViewModel.isRecording {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            cameraViewModel.switchToWideAngle()
                        }) {
                            Image(systemName: "camera.fill") // Example icon for wide angle
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            cameraViewModel.switchToStandard()
                        }) {
                            Image(systemName: "camera.viewfinder") // Example icon for standard view
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    Spacer()
                }
            }
            
            if !cameraViewModel.hasCameraAccess {
                Text("Camera access denied. Please enable in settings.")
                    .foregroundColor(.white)
                    .background(Color.red)
                    .transition(.opacity)
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
            
            cameraViewModel.channelId = navigation.channelId
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

class CameraViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var channelId: String = ""
    
    @Published var isRecording = false
    @Published var isVideoRecorded = false
    @Published var showingPreview = false
    @Published var showZoomHint = true
    @Published var hasCameraAccess = true
    @Published var isUploading = false
    @Published var showingAlert = false
    
    // Zoom factors for different camera modes
    var zoomFactor: CGFloat = 1.0 // Current zoom factor
    var wideAngleZoomFactor: CGFloat = 1.0 // Last zoom factor for wide-angle mode
    var standardZoomFactor: CGFloat = 1.0 // Last zoom factor for standard mode
    
    private var currentDevice: AVCaptureDevice?
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    var videoURL: URL?
    
    let keychainForAws = AwsKeychainStorage()
    private let uploadManager: UploadManager

    override init() {
        uploadManager = UploadManager(keychainForAws: keychainForAws)
        super.init()
    }
    
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
   
    func uploadFiles(imageURL: URL) async throws {
        isUploading = true
        
        // Use the UploadManager to upload the image and video
        Task {
            try await uploadManager.uploadImage(imageURL: imageURL, channelId: channelId)
            if let videoURL = videoURL {
                try await uploadManager.uploadVideo(videoURL: videoURL, channelId: channelId)
            }
        }
        
        isUploading = false
        showingPreview = false
        showingAlert = true
    }
    
    // MARK: - Zoom Functionality
    func zoom(factor: CGFloat) {
        // Set the zoom factor based on user interaction
        guard let device = AVCaptureDevice.default(for: .video), device.activeFormat.videoMaxZoomFactor > factor else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
            
            // Save the zoom factor globally
            self.zoomFactor = factor
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }
    
    // Function to switch between wide and normal lenses and restore zoom
    func switchToWideAngle() {
        guard let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Wide angle camera not available")
            return
        }
        
        // Store the current zoom factor for the standard camera
        standardZoomFactor = zoomFactor
        
        // Switch camera and restore last zoom level for wide-angle
        switchCamera(to: wideDevice)
        zoom(factor: wideAngleZoomFactor)
    }
    
    func switchToStandard() {
        guard let normalDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else {
            print("Standard telephoto camera not available")
            return
        }
        
        // Store the current zoom factor for the wide-angle camera
        wideAngleZoomFactor = zoomFactor
        
        // Switch camera and restore last zoom level for standard camera
        switchCamera(to: normalDevice)
        zoom(factor: standardZoomFactor)
    }
    
    private func switchCamera(to device: AVCaptureDevice) {
        session.beginConfiguration()
        
        // Remove all inputs
        session.inputs.forEach { session.removeInput($0) }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentDevice = device
            }
        } catch {
            print("Failed to switch camera: \(error)")
        }
        
        session.commitConfiguration()
    }
}
