//
//  ConnectRelay.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import SwiftUI

struct ConnectRelay: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        Text("Connected Relays")
        ForEach(Array(viewModel.relayPool.relays), id: \.self) { relay in
            Text("🟢 \(relay.url.absoluteString)")
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = relay.url.absoluteString
                    }) {
                        Text("Copy")
                    }
                }
        }
    }
}

#Preview {
    ConnectRelay()
}
