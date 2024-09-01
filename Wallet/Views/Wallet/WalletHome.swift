//
//  WalletHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct WalletHome: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics ") {
                openURL(url)
            }
        } label: {
            Label("Get Help", systemImage: "person.fill.questionmark")
        }
    }
}

#Preview {
    WalletHome()
}
