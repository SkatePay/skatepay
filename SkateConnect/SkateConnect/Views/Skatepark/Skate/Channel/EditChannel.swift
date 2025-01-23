//
//  EditChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import CryptoKit
import NostrSDK
import SwiftUI

func encryptChannelInviteToString(channel: Channel) -> String? {
    let keyString = "SKATECONNECT"
    let keyData = Data(keyString.utf8)
    let hashedKey = SHA256.hash(data: keyData)
    let symmetricKey = SymmetricKey(data: hashedKey)
    
    do {
        let jsonData = try JSONEncoder().encode(channel)
        let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
        return sealedBox.combined?.base64EncodedString()
    } catch {
        print("Error encrypting channel: \(error)")
        return nil
    }
}

func decryptChannelInviteFromString(encryptedString: String) -> Channel? {
    let keyString = "SKATECONNECT"
    let keyData = Data(keyString.utf8)
    let hashedKey = SHA256.hash(data: keyData)
    let symmetricKey = SymmetricKey(data: hashedKey)
    
    do {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            print("Error decoding Base64 string")
            return nil
        }
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        return try JSONDecoder().decode(Channel.self, from: decryptedData)
    } catch {
        print("Error decrypting channel: \(error)")
        return nil
    }
}

struct EditChannel: View {
    @Environment(\.modelContext) private var context
    
    @ObservedObject var navigation = Navigation.shared
    @State private var isInviteCopied = false
    
    let keychainForNostr = NostrKeychainStorage()
    
    private var lead: Lead?
    private var channel: Channel?
    
    init(lead: Lead?, channel: Channel?) {
        self.lead = lead
        self.channel = channel
    }
    
    private func createInviteString() -> String {
        guard let channelId = navigation.channelId else {
            print("Error: Channel ID is nil.")
            return ""
        }
        
        var inviteString = channelId
        
        if let event = navigation.channel {
            inviteString = event.id
            
            if var channel = parseChannel(from: event) {
                channel.event = navigation.channel
                if let ecryptedString = encryptChannelInviteToString(channel: channel) {
                    inviteString = ecryptedString
                }
            }
        }
        return inviteString
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
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = channel.about
                                }) {
                                    Text("Copy description")
                                }
                            }
                    }
                    
                    Section ("Id") {
                        Text("\(lead.channelId)")
                            .contextMenu {
                                Button(action: {
                                    shareChannel(lead.channelId)
                                }) {
                                    Text("Open in Browser")
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = "channel_invite:\(createInviteString())"
                                    isInviteCopied = true
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        isInviteCopied = false
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "link")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.blue)
                                        Text("Copy Invite")
                                            .font(.caption)
                                    }
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = lead.channelId
                                }) {
                                    Text("Copy channelId")
                                }
                            }
                    }
                    
                    
                    if let pubkey = lead.event?.pubkey {
                        if let publicKeyForMod = PublicKey(hex: pubkey),
                           let npub = keychainForNostr.account?.publicKey.npub {
                            Text(publicKeyForMod.npub == npub ? "Owner: You" : "Owner: \(friendlyKey(npub: publicKeyForMod.npub))")
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
                            name: "Private Channel \(lead.channelId.suffix(3))",
                            address: "",
                            state: "",
                            icon: "",
                            note: "",
                            latitude: AppData().landmarks[0].locationCoordinate.latitude,
                            longitude: AppData().landmarks[0].locationCoordinate.longitude,
                            channelId: lead.channelId
                        )
                        
                        Button(action: {
                            context.insert(spot)
                        }) {
                            Text("Add to Address Book")
                        }
                    }
                }
            }
            .animation(.easeInOut, value: isInviteCopied)
        }
        
        if isInviteCopied {
            Text("Invite copied!")
                .foregroundColor(.green)
                .padding(.top, 10)
                .transition(.opacity)
        }
    }
}

#Preview {
    EditChannel(lead: nil, channel: Channel(name: "", about: "", picture: "", relays: [Constants.RELAY_URL_SKATEPARK], event: nil))
}
