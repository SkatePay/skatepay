//
//  DeckTrackerView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI
import AVFoundation

struct DeckTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: Navigation
    
    @State private var deckImage: UIImage?
    @State private var fileURL: URL?
    @State private var captureTrigger = false
    
    var body: some View {
        VStack {
            // Camera View
            DeckTrackerCamera(
                capturedImage: $deckImage,
                captureTrigger: $captureTrigger,
                onImageCaptured: { image, fileURL in
                    print("Captured image: \(image.size)")
                    print("Saved to: \(fileURL.path)")
                    
                    self.fileURL = fileURL
                }
            )
            // Maintain a portrait aspect ratio even if scaled down
            .aspectRatio(3/4, contentMode: .fit)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            
            Spacer()
            
            // Capture Button
            Button(action: {
                captureTrigger = true
            }) {
                Text("Capture Deck")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(deckImage != nil) // Disable if image already exists
            
            // Preview and Continue
            if let deckImage = deckImage {
                VStack {
                    // Rotate the captured image 90° for landscape presentation
                    Image(uiImage: deckImage)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(90))
                        .frame(height: 200)
                        .padding()
                    
                    Button("Continue") {
                        if let fileURL = self.fileURL {
                            navigation.path.append(NavigationPathType.deckDetails(image: deckImage, fileURL: fileURL))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
        .navigationTitle("Scan Your Deck")
        .navigationBarTitleDisplayMode(.inline)
    }
}
