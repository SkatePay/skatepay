//
//  WalletView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift

struct WalletView: View {
    @Binding var host: Host
    
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    @State private var publicKey: String?
    
    let saveAction: ()->Void
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let noValueString = ""
    
    @Environment(\.openURL) private var openURL
    
    let accountStorage = KeychainAccountStorage()
    
    var body: some View {
        NavigationView {
            
            Form {
                Button {
                    if let url = URL(string: "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics") {
                        openURL(url)
                    }
                } label: {
                    Label("Get Help", systemImage: "person.fill.questionmark")
                }
                
                Section ("NOSTR") {
                    Button("🔁 Cycle Keys") {
                        keypair = Keypair()
                        //                privateKey = keypair?.privateKey.hex ?? noValueString
                        //                publicKey = keypair?.publicKey.hex ?? noValueString
                        
                        nsec = keypair?.privateKey.nsec ?? ""
                        npub = keypair?.publicKey.npub ?? ""
                        
                        host.privateKey = keypair?.privateKey.hex ?? noValueString
                        host.publicKey = keypair?.publicKey.hex ?? noValueString
                        
                        host.nsec = keypair?.privateKey.nsec ?? ""
                        host.npub = keypair?.publicKey.npub ?? ""
                        
                        saveAction()
                    }
                }
                
                Section("npub") {
                    Text(npub ?? host.npub)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = npub ?? host.npub
                            }) {
                                Text("Copy npub")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = publicKey ?? host.publicKey
                            }) {
                                Text("Copy phex")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = nsec ?? host.nsec
                            }) {
                                Text("Copy nsec")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = keypair?.publicKey.hex ?? host.privateKey
                            }) {
                                Text("Copy shex")
                            }
                        }
                }
                
                Section ("Solana") {
                    NavigationLink {
                        ImportWallet()
                    } label: {
                        Text("💼 Wallet Methods")
                    }
                }
                
                Section("publicKey") {
                    Text(accountStorage.account?.publicKey.base58EncodedString ?? "" )
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = publicKey
                            }) {
                                Text("Copy")
                            }
                        }
                }
                
                Button("💁 Request Token Reward") {
                    Task {
                        print("Requesting...")
                    }
                }
                
            }
        }
    }
}

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
