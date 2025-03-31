//
//  DeckTrackerCamera.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import SwiftUI
import AVFoundation

struct DeckTrackerCamera: View {
    @Binding var capturedImage: UIImage?
    @Binding var captureTrigger: Bool
    var onImageCaptured: ((UIImage, URL) -> Void)?

    private var isCameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var body: some View {
        ZStack {
            if isCameraAuthorized {
                DeckTrackerPreview(
                    capturedImage: $capturedImage,
                    onImageCaptured: onImageCaptured,
                    captureTrigger: $captureTrigger
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                disabledView
            }
        }
    }

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
    var onImageCaptured: ((UIImage, URL) -> Void)?
    @Binding var captureTrigger: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        DispatchQueue.global(qos: .userInitiated).async {
            if let captureDevice = AVCaptureDevice.default(for: .video) {
                do {
                    let input = try AVCaptureDeviceInput(device: captureDevice)
                    if captureSession.canAddInput(input) {
                        captureSession.addInput(input)
                    }

                    DispatchQueue.main.async {
                        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.frame = view.bounds
                        previewLayer.videoGravity = .resizeAspectFill

                        // Handle orientation
                        if let connection = previewLayer.connection {
                            if connection.isVideoRotationAngleSupported(90) {
                                connection.videoRotationAngle = 90
                            }
                        }

                        view.layer.addSublayer(previewLayer)
                    }

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
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
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
            guard let photoOutput = photoOutput else { return }
            
            var photoSettings = AVCapturePhotoSettings()
            photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            photoSettings.photoQualityPrioritization = .quality
            
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            }
            
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
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
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "deck_photo_\(UUID().uuidString).jpg"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try imageData.write(to: fileURL)
                print("Photo saved to temporary file: \(fileURL)")
                
                DispatchQueue.main.async {
                    self.parent.capturedImage = image
                    self.parent.onImageCaptured?(image, fileURL)
                }
            } catch {
                print("Error saving photo to file: \(error)")
                DispatchQueue.main.async {
                    self.parent.capturedImage = image
                }
            }
        }
    }
}
