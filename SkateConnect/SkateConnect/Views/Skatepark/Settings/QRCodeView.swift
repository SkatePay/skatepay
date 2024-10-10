//
//  QRCodeView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/9/24.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let npub: String
    
    var body: some View {
        VStack {
            if let qrImage = generateQRCode(from: npub) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } else {
                Text("Failed to generate QR Code")
            }
        }
        .padding()
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 10, y: 10)

        if let output = filter.outputImage?.transformed(by: transform) {
            let context = CIContext()
            if let cgImage = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}
