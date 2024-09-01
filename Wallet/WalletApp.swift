//
//  WalletApp.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftUI

@main
struct WalletApp: App {
    @StateObject var relayPool = try! RelayPool(relayURLs: [
//        URL(string: "wss://relay.damus.io")!,
//        URL(string: "wss://relay.snort.social")!,
//        URL(string: "wss://nos.lol")!
        URL(string: "wss://relay.snort.social")!
    ])
    
    @State private var modelData = ModelData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environment(modelData)
            .environmentObject(relayPool)
        }
    }
}

