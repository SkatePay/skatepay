//
//  TickerOverlay.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import os

import SwiftUI

struct TickerOverlay: View {
    let log = OSLog(subsystem: "SkateConnect", category: "Overlay")

    @EnvironmentObject private var stateManager: StateManager
    @EnvironmentObject private var apiService: API
    @EnvironmentObject private var network: Network
    
    var body: some View {
        GeometryReader { geometry in
            if stateManager.isShowingLoadingOverlay && network.connected {
                HStack(spacing: 8) {  // Slightly more spacing
                    MarqueeText(text: debugOutput())
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)  // More balanced spacer
                    
                    Button(action: {
                        withAnimation {
                            stateManager.isShowingLoadingOverlay = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))  // Restored original button size
                    }
                }
                .padding(.horizontal, 12)  // Slightly more side padding
                .padding(.vertical, 8)    // Comfortable vertical padding
                .background(Color.black.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 36)        // Taller to accommodate larger font
                .position(x: geometry.size.width / 2, y: 16)
            }
        }
        .onAppear {
            os_log("🚀 %s", log: log, type: .info, network.connected ? "Connected" : "Not Connected")
        }
    }
    
    func debugOutput() -> String {
        if let error = apiService.error {
            return error.localizedDescription
        }
        
        return apiService.isLoading ? "Loading..." : " 🟢 Welcome to SkateConnect – Let's Skate! ℹ️ Say 'Hi' in HQ if you see this."
    }
}

struct MarqueeText: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var textSize: CGSize = .zero
    @State private var animationID = UUID() // Unique ID to manage animations
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let textWidth = textSize.width
            
            if textWidth > containerWidth {
                ZStack {
                    Text(text)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .fixedSize()
                        .offset(x: offset)
                        .frame(height: 32)
                    
                    Text(text)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .fixedSize()
                        .offset(x: offset + textWidth)
                        .frame(height: 32)
                }
                .onAppear {
                    startAnimation(textWidth: textWidth)
                }
                .onChange(of: text) {
                    // Reset and restart animation when text changes
                    startAnimation(textWidth: textSize.width)
                }
            } else {
                Text(text)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .frame(height: 32)
            }
        }
        .frame(height: 32)
        .background(
            Text(text)
                .font(.headline)
                .bold()
                .fixedSize()
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { textSize = geo.size }
                        .onChange(of: text) {
                            textSize = geo.size
                        }
                })
                .hidden()
        )
        .clipped()
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private func startAnimation(textWidth: CGFloat) {
        // Cancel any existing animation
        offset = 0
        animationID = UUID() // Invalidate previous animations
        
        // Start new animation with the current ID captured
        let currentAnimationID = animationID
        withAnimation(.linear(duration: Double(textWidth) / 50.0).repeatForever(autoreverses: false)) {
            if currentAnimationID == animationID { // Only proceed if ID hasn't changed
                offset = -textWidth
            }
        }
    }
}
