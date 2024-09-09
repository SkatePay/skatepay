//
//  DirectMessage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import SwiftUI
import NostrSDK

struct DirectMessage: View, EventCreating {
    @EnvironmentObject var viewModel: ContentViewModel
    
    @State var recipientPublicKey = ""
    @State private var recipientPublicKeyIsValid: Bool = false
    
    let keychainForNostr = NostrKeychainStorage()
    
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
                      let senderKeyPair = myKeypair() else {
                    return
                }
                do {
                    let directMessage = try legacyEncryptedDirectMessage(withContent: message,
                                                                         toRecipient: recipientPublicKey,
                                                                         signedBy: senderKeyPair)
                    viewModel.relayPool.publishEvent(directMessage)
                    
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
    
    private func myKeypair() -> Keypair? {
        return Keypair(hex: (keychainForNostr.account?.privateKey.hex)!)
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
        recipientPublicKeyIsValid
    }
}

#Preview {
    DirectMessage(recipientPublicKey: DemoHelper.validHexPublicKey.wrappedValue)
}
