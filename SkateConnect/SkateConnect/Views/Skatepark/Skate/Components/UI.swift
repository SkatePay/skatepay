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
