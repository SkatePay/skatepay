//
//  WalletApp.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftUI
import SwiftData

struct Constants {
    static let RELAY_URL_DAMUS = "relay.damus.io"
    static let RELAY_URL_PRIMAL = "wss://relay.primal.net"
    // "wss://relay.snort.social"
    // "wss://nos.lol"
}

@main
struct WalletApp: App {
    @State private var modelData = ModelData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Friend.self, Spot.self])
                .environment(modelData)
        }
    }
}

