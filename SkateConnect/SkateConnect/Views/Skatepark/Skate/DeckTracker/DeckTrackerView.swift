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
    @State private var captureTrigger = false
    
    var body: some View {
        VStack {
            // Camera View
            DeckTrackerCamera(
                capturedImage: $deckImage,
                onImageCaptured: { image in
                    // Handle the captured skateboard image
                    print("Deck image captured: \(image.size)")
                },
                captureTrigger: $captureTrigger
            )
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
            .disabled(deckImage != nil) // Disable if we already have an image
            
            // Preview and Continue
            if let deckImage = deckImage {
                VStack {
                    Image(uiImage: deckImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .padding()
                    
                    Button("Continue") {
                        // Process the captured deck image
                        navigation.path.append(NavigationPathType.deckDetails(image: deckImage))
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
