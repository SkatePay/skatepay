//
//  EditChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI

struct EditChannel: View {
    @EnvironmentObject var viewModelForChannelFeed: ChannelFeedViewModel
    
    let keychainForNostr = NostrKeychainStorage()
    
    private var lead: Lead?
    private var channel: Channel?

    init(lead: Lead?, channel: Channel?) {
        self.lead = lead
        self.channel = channel
    }
    
    var body: some View {
        if let lead = lead {
            Form {
                Text("📡 Edit Channel")
                if let channel = lead.channel {
                    Section ("Name") {
                        Text("\(channel.name)")
                    }
                    Section ("Description") {
                        Text("\(channel.about)")
                    }
                    
                    Section ("Id") {
                        Text("\(lead.eventId)")
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = lead.eventId
                                    }) {
                                        Text("Copy channelId")
                                    }
                                }
                    }
    

                    if let pubkey = lead.event?.pubkey {
                        if let publicKeyForMod = PublicKey(hex: pubkey),
                           let npub = keychainForNostr.account?.publicKey.npub {
                            Text(publicKeyForMod.npub == npub ? "Mod: You" : "Mod: \(publicKeyForMod.npub)")
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
}

#Preview {
    EditChannel(lead: nil, channel: Channel(name: "", about: "", picture: "", relays: [Constants.RELAY_URL_PRIMAL]))
}
