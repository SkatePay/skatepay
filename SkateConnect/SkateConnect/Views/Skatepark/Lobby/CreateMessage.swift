//
//  CreateMessage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import SwiftUI
import SwiftData
import NostrSDK

struct CreateMessage: View, EventCreating {
    @EnvironmentObject var viewModel: ContentViewModel
    
    @ObservedObject var networkConnections = NetworkConnections.shared
    @ObservedObject var navigation = NavigationManager.shared

    @Query(filter: #Predicate<Friend> { $0.npub != ""  }, sort: \Friend.name)
    private var friends: [Friend]

    let keychainForNostr = NostrKeychainStorage()

    @State private var showingAlert = false

    @State var npub = ""
    @State private var recipientPublicKeyIsValid: Bool = false
    @State private var message: String = ""
    
    @State private var selectedOption = 0
    
    var body: some View {
        Text("Nostr Message")
        Form {
            Section("Recipient") {
                if (friends.count > 0) {
                    Picker("Friend", selection: $selectedOption) {
                        ForEach(Array(friends.enumerated()), id: \.element.id) { idx, friend in
                            Text(friend.name).tag(idx)
                        }
                    }
                } else {
                    Text("Add Friends in Lobby")
                }
                NostrKeyInput(key: $npub,
                              isValid: $recipientPublicKeyIsValid,
                              type: .public)
                Button("Scan Barcode") {
                    navigation.isShowingBarcodeScanner = true
                }
            }
            
            Section("Content") {
                TextField("message", text: $message)
            }
            Button("Send") {
                var key = npub
                if npub.isEmpty {
                    let friend = friends[selectedOption]
                    key = friend.npub
                }

                do {
                    guard let recipientPublicKey = PublicKey(npub: key) else {
                        print("Failed to create PublicKey from npub.")
                        return
                    }
                    
                    guard let senderKeyPair = myKeypair() else {
                        print("Failed to get sender's key pair.")
                        return
                    }
                    
                    let directMessage = try legacyEncryptedDirectMessage(withContent: message,
                                                                         toRecipient: recipientPublicKey,
                                                                         signedBy: senderKeyPair)
                    
                    networkConnections.reconnectRelaysIfNeeded()
                    networkConnections.relayPool.publishEvent(directMessage)
                    
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
        .fullScreenCover(isPresented: $navigation.isShowingBarcodeScanner) {
            NavigationView {
                BarcodeScanner()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .barcodeScanned)) { notification in
            
            func cleanNostrPrefix(_ input: String) -> String {
                return input.replacingOccurrences(of: "nostr:", with: "")
            }
            
            if let scannedText = notification.userInfo?["scannedText"] as? String {
                self.npub = cleanNostrPrefix(scannedText)
            }
        }
    }
    
    private func myKeypair() -> Keypair? {
        return Keypair(hex: (keychainForNostr.account?.privateKey.hex)!)
    }
    
    private func readyToSend() -> Bool {
        (!message.isEmpty &&
        (recipientPublicKeyIsValid || !friends.isEmpty))
    }
}

#Preview {
    CreateMessage(npub: AppData().users[0].npub)
}
