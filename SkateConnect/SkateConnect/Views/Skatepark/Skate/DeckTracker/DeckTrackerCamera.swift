//
//  DeckTrackerCamera.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import SwiftUI
import AVFoundation

// Updated Camera View
struct DeckTrackerCamera: UIViewRepresentable {
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
        var parent: DeckTrackerCamera
        var photoOutput: AVCapturePhotoOutput?
        
        init(parent: DeckTrackerCamera) {
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
