//
//  DirectMessage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import SwiftUI
import NostrSDK

struct DirectMessage: View, EventCreating {
    @EnvironmentObject var relayPool: RelayPool
    
    @State var recipientPublicKey = ""
    @State private var recipientPublicKeyIsValid: Bool = false

    @State var senderPrivateKey = ""
    @State private var senderPrivateKeyIsValid: Bool = false

    @State private var showingAlert = false

    @State private var message: String = ""
    
    var body: some View {
        Text("Message")
        Form {

            Section("Recipient") {
                NostrKeyInput(key: $recipientPublicKey,
                                    isValid: $recipientPublicKeyIsValid,
                                    type: .public)
            }
            Section("Content") {
                TextField("Enter a message.", text: $message)
            }
            Button("Send") {
                guard let recipientPublicKey = publicKey(),
                      let senderKeyPair = keypair() else {
                    return
                }
                do {
                    let directMessage = try legacyEncryptedDirectMessage(withContent: message,
                                                                         toRecipient: recipientPublicKey,
                                                                         signedBy: senderKeyPair)
                    relayPool.publishEvent(directMessage)
                    
                    showingAlert = true
                } catch {
                    print(error.localizedDescription)
                }
            }
            .alert("Message sent", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .disabled(!readyToSend())
        }
    }

    private func keypair() -> Keypair? {
        if senderPrivateKey.contains("nsec") {
            return Keypair(nsec: senderPrivateKey)
        } else {
            return Keypair(hex: senderPrivateKey)
        }
    }

    private func publicKey() -> PublicKey? {
        if recipientPublicKey.contains("npub") {
            return PublicKey(npub: recipientPublicKey)
        } else {
            return PublicKey(hex: recipientPublicKey)
        }
    }

    private func readyToSend() -> Bool {
        !message.isEmpty &&
        recipientPublicKeyIsValid &&
        senderPrivateKeyIsValid
    }
}

#Preview {
    DirectMessage(recipientPublicKey: DemoHelper.validHexPublicKey.wrappedValue)
}
