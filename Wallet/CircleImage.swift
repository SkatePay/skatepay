//
//  CircleImage.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct CircleImage: View {
    var body: some View {
        Image("venice-skate-park")
            .clipShape(Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 4)
            }
            .shadow(radius: 7)
    }
}

#Preview {
    CircleImage()
}
