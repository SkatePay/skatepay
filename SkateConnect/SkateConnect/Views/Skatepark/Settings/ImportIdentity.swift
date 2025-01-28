//
//  ImportIdentity.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import NostrSDK
import SwiftUI

struct ImportIdentity: View {
    @Environment(\.openURL) private var openURL

    @EnvironmentObject var lobby: Lobby

    @State private var showingAlert = false
    @State private var privateKey: String = ""
    @State private var account: Keypair!
    
    let keychainForNostr = NostrKeychainStorage()
    
    var interfaceForPublicKey: some View {
        Form {
            Section("NOSTR PUBKEY") {
                Text(keychainForNostr.account?.publicKey.npub ?? "" )
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = keychainForNostr.account?.publicKey.npub
                        }) {
                            Text("Copy public key")
                        }
                        
                        Button(action: {
                            let stringForCopyPaste: String
                            if let nsec = keychainForNostr.account?.privateKey.nsec {
                                stringForCopyPaste = nsec
                            } else {
                                stringForCopyPaste = ""
                            }
                            
                            UIPasteboard.general.string = stringForCopyPaste
                        }) {
                            Text("Copy secret key")
                        }
                    }
            }
            Section("Instructions") {
                Text("Hold key to copy")
            }
        }
      }
    
    var interfaceForWalletCreation: some View {
        Form {
            Text("New Identity")

            Section("Private Key") {
                TextField("Enter nsec", text: $privateKey)
            }
            
            Button("Import Identity") {
                Task {
                    if (privateKey.isEmpty) {
                        keychainForNostr.clear()
                        return
                    }
                    
                    account = Keypair(nsec: privateKey)

                    do {
                        self.lobby.clear()
                        try keychainForNostr.save(account)
                        showingAlert = true
                    } catch {
                        print(error)
                    }
                }
            }
            .alert("Identity created.", isPresented: $showingAlert) {
                Button("Ok", role: .cancel) { }
            }
            
            Button("Create Identity") {
                Task {
                    account = Keypair()
                    do {
                        try keychainForNostr.save(account)
                        showingAlert = true
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
    
    var body: some View {
        interfaceForPublicKey
        interfaceForWalletCreation
    }
}

#Preview {
    ImportIdentity()
}
