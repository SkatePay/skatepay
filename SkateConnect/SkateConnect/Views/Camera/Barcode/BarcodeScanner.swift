//
//  BarcodeScanner.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import SwiftUI
import AVFoundation
import Vision

struct BarcodeScanner: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var navigation: Navigation
    
    @State private var scannedText = ""

    var body: some View {
        VStack {
            if !scannedText.isEmpty {
                Text("Scanned: \(scannedText)")
                    .padding()
            }
            ScannerView(scannedText: $scannedText)
                .ignoresSafeArea()
        }
        .navigationTitle("Scan Barcode")
        .onDisappear {
            NotificationCenter.default.post(name: .barcodeScanned, object: nil, userInfo: ["scannedText": scannedText])
        }
    }
}

#Preview {
    BarcodeScanner()
}
