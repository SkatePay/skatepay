//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import CryptoKit
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

struct ToolBoxView: View {
    @State private var isInviteCopied = false
    
    @ObservedObject var navigation = Navigation.shared
    
    private func createInviteString() -> String {
        var inviteString = navigation.channelId
        
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
        VStack {
            Text("🧰 Toolbox")
                .font(.headline)
                .padding(.top)

            Divider()

                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: 20) {
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
                     }
                     .padding(.horizontal)
                 }
             
            Spacer()
            
            if isInviteCopied {
                Text("Invite copied!")
                    .foregroundColor(.green)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .animation(.easeInOut, value: isInviteCopied)
    }
}

#Preview {
    ToolBoxView()
}
