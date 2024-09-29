//
//  ScannerView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import SwiftUI
import AVFoundation
import Vision

struct ScannerView: UIViewRepresentable {
    @Binding var scannedText: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
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
                
                captureSession.startRunning()
                
                let dataOutput = AVCaptureVideoDataOutput()
                dataOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
                if captureSession.canAddOutput(dataOutput) {
                    captureSession.addOutput(dataOutput)
                }
            } catch {
                print(error)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scannedText: $scannedText)
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var scannedText: Binding<String>
        
        init(scannedText: Binding<String>) {
            self.scannedText = scannedText
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up)
            do {
                try requestHandler.perform([VNDetectBarcodesRequest { request, error in
                    guard let codes = request.results as? [VNBarcodeObservation],
                          let code = codes.first else { return }
                    
                    DispatchQueue.main.async {
                        self.scannedText.wrappedValue = code.payloadStringValue ?? ""
                    }
                }])
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    ScannerView(scannedText: .constant(""))
}
