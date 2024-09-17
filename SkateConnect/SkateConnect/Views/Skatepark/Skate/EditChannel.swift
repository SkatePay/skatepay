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
    @Environment(\.modelContext) private var context

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
                Text("📡 Channel Info")
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
                            Text(publicKeyForMod.npub == npub ? "Owner: You" : "Owner: \(publicKeyForMod.npub)")
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = publicKeyForMod.npub
                                    }) {
                                        Text("Copy npub")
                                    }
                                }
                        }
                    }
                    
                    if (channel.name == "Private Channel") {
                        let spot = Spot(
                            name: "Private Channel \(lead.eventId.suffix(3))",
                            address: "",
                            state: "",
                            note: "",
                            latitude: AppData().landmarks[0].locationCoordinate.latitude,
                            longitude: AppData().landmarks[0].locationCoordinate.longitude,
                            channelId: lead.eventId
                        )
                        
                        Button(action: {
                            context.insert(spot)
                        }) {
                            Text("Add to Address Book")
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
