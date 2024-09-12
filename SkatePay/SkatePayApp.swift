//
//  SkatePayApp.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import NostrSDK
import SwiftUI
import SwiftData

extension SkatePayApp {
    static let RELAY_URL_DAMUS = "relay.damus.io"
    static let RELAY_URL_PRIMAL = "wss://relay.primal.net"
    static let SOLANA_MINT_ADDRESS = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
    static let SOLANA_TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    static let SOLANA_TOKEN_LIST_URL =  "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
    static let NPUB_HUB = "npub1ydcksr7z0a2mk0fnhqkfd0dkgapdgqg2l39mfcuwwwuaeuf6r6qqzq7z7v"
    static let NCHANNEL_ID = "daa690d701274549da87efbc969bb6b64a5367dbcbef26e116776053696e72ee"
}

@main
struct SkatePayApp: App {
    @State private var modelData = SkatePayData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Friend.self, Spot.self])
                .environment(modelData)
        }
    }
}
