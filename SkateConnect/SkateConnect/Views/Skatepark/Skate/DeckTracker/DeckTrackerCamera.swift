//
//  DeckTrackerCamera.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import SwiftUI
import AVFoundation

import SwiftUI
import AVFoundation

struct DeckTrackerCamera: View {
    @Binding var capturedImage: UIImage?
    @Binding var captureTrigger: Bool
    var onImageCaptured: ((UIImage) -> Void)?

    // Computed property to check camera authorization status
    private var isCameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var body: some View {
        ZStack {
            if isCameraAuthorized {
                // Use the renamed DeckTrackerPreview class
                DeckTrackerPreview(capturedImage: $capturedImage,
                                   onImageCaptured: onImageCaptured, captureTrigger: $captureTrigger)
                    .edgesIgnoringSafeArea(.all)
            } else {
                disabledView
            }
        }
    }
    
    // SwiftUI view for the disabled camera state
    private var disabledView: some View {
        VStack {
            Text("Camera is disabled. Please enable it in your phone's settings.")
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(8)
                .transition(.opacity)
            
            Button(action: {
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
}

struct DeckTrackerPreview: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    var onImageCaptured: ((UIImage) -> Void)?
    @Binding var captureTrigger: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        if let captureDevice = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
                
                let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.frame = view.bounds
                previewLayer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(previewLayer)
                
                let photoOutput = AVCapturePhotoOutput()
                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                    context.coordinator.photoOutput = photoOutput
                }
                
                captureSession.startRunning()
            } catch {
                print("Camera setup error: \(error)")
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Trigger photo capture when the binding changes
        if captureTrigger {
            context.coordinator.capturePhoto()
            DispatchQueue.main.async {
                captureTrigger = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: DeckTrackerPreview
        var photoOutput: AVCapturePhotoOutput?
        
        init(parent: DeckTrackerPreview) {
            self.parent = parent
        }
        
        func capturePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput?.capturePhoto(with: settings, delegate: self)
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photo: AVCapturePhoto,
                         error: Error?) {
            if let error = error {
                print("Photo capture error: \(error)")
                return
            }
            
            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.parent.capturedImage = image
                self.parent.onImageCaptured?(image)
            }
        }
    }
}
