//
//  EditChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import NostrSDK
import SwiftUI

struct EditChannel: View {
    @EnvironmentObject var viewModelForChannelFeed: ChannelFeedViewModel
    
    let keychainForNostr = NostrKeychainStorage()
    
    var body: some View {
        if let event = viewModelForChannelFeed.metadataForChannel {
            List {
                Section ("Channel Info") {
                    Text("Name: \(event.content)")
                    Text("Id: \(event.id)")
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = event.id
                            }) {
                                Text("Copy channelId")
                            }
                        }
                    Text("Description: ")
                    
                    if let publicKeyForMod = PublicKey(hex: event.pubkey),
                       let npub = keychainForNostr.account?.publicKey.npub {
                        Text(publicKeyForMod.npub == npub ? "You" : "Mod: \(publicKeyForMod.npub)")
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = publicKeyForMod.npub
                                }) {
                                    Text("Copy npub")
                                }
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    EditChannel()
}
