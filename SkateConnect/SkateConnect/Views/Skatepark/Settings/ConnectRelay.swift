//
//  ConnectRelay.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import NostrSDK
import SwiftUI

struct ConnectRelay: View {    
    @ObservedObject var network = Network.shared

    private var relayPool: RelayPool {
        return network.getRelayPool()
    }
    
    var body: some View {
        Text("Connected Relays")
        ForEach(Array(relayPool.relays), id: \.self) { relay in
            Text("\(relay.state == .connected ? "🟢" : "🔴" ) \(relay.url.absoluteString)")
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = relay.url.absoluteString
                    }) {
                        Text("Copy")
                    }
                }
        }
        
        Button("Reconnect 🔄") {
            network.reconnectRelaysIfNeeded()
        }
    }
}

#Preview {
    ConnectRelay()
}
