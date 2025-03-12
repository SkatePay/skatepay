//
//  CameraPreview.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/11/25.
//

import os

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        DispatchQueue.main.async {
            uiView.forceUpdatePreviewLayerFrame()
        }
    }
}

// Custom UIView subclass to handle resizing
class PreviewView: UIView {
    let log = OSLog(subsystem: "SkateConnect", category: "Camera")

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func forceUpdatePreviewLayerFrame() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        previewLayer.frame = bounds
        previewLayer.setNeedsDisplay()
        os_log("📸 Preview layer updated to: %{public}@", log: log, type: .info, String(describing: previewLayer.frame))
    }
}
