//
//  SettingsView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import SwiftUI
import NostrSDK
import SolanaSwift
import Combine

struct SettingsView: View {
    @Binding var host: Host
    
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    @Environment(\.openURL) private var openURL
    
    let keychainForNostr = NostrKeychainStorage()
    
    var body: some View {
        NavigationView {
            List {
                Section ("NOSTR") {
                    if let publicKey = keychainForNostr.account?.publicKey.npub {
                        Text("\(publicKey.prefix(8))...\(publicKey.suffix(8))")
                            .contextMenu {
                                if let npub = keychainForNostr.account?.publicKey.npub {
                                    Button(action: {
                                        UIPasteboard.general.string = npub
                                    }) {
                                        Text("Copy npub")
                                    }
                                }
                                
                                if let nsec = keychainForNostr.account?.privateKey.nsec {
                                    Button(action: {
                                        UIPasteboard.general.string = nsec
                                    }) {
                                        Text("Copy nsec")
                                    }
                                }
                                
                                if let phex = keychainForNostr.account?.publicKey.hex {
                                    Button(action: {
                                        UIPasteboard.general.string = phex
                                    }) {
                                        Text("Copy phex")
                                    }
                                }
                                
                                if let shex = keychainForNostr.account?.privateKey.hex {
                                    Button(action: {
                                        UIPasteboard.general.string = shex
                                    }) {
                                        Text("Copy shex")
                                    }
                                }
                            }
                    } else {
                        Text("Create new keys")
                    }
                    
                    NavigationLink {
                        ImportIdentity()
                    } label: {
                        Text("🔑 Keys")
                    }
                    NavigationLink {
                        ConnectRelay()
                    } label: {
                        Text("📡 Relays")
                    }
                }
                
                Button("💁 Get Help") {
                    Task {
                        if let url = URL(string: ProRobot.HELP_URL_SKATECONNECT) {
                            openURL(url)
                        }
                    }
                }
                
                Button("Reset App") {
                    Task {
                        keychainForNostr.clear()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(host: .constant(Host()))
}
