//
//  UI.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation
import SwiftUI

struct MarqueeText: View {
    let text: String
    @State private var offsetX: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        Text(text)
            .font(.headline)
            .bold()
            .foregroundColor(.white)
            .offset(x: offsetX)
            .onAppear {
                let baseAnimation = Animation.linear(duration: 8.0).repeatForever(autoreverses: false)
                withAnimation(baseAnimation) {
                    offsetX = -UIScreen.main.bounds.width
                }
            }
    }
}

struct DebugView<Content: View>: View {
    let content: Content
    let id = UUID()
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        print("Creating DebugView with ID: \(id)")
    }
    
    var body: some View {
        content.onAppear {
            print("DebugView with ID: \(id) appeared")
        }
    }
}
