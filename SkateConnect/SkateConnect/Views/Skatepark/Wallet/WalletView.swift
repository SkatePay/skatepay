//
//  WalletView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import ConnectFramework
import SwiftUI
import NostrSDK
import SolanaSwift
import Combine

struct WalletView: View {
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    
    @Binding var host: Host
    
    @StateObject private var walletManager = WalletManager()
    
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    let saveAction: ()->Void
    
    @Environment(\.openURL) private var openURL
    
    let keychainForSolana = SolanaKeychainStorage()
    let keychainForNostr = NostrKeychainStorage()
    
    var assetBalance: some View {
        Section("Asset Balance") {
            Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
            ForEach(walletManager.accounts) { account in
                Text("\(account.lamports) $\(account.symbol.prefix(3))")
                    .contextMenu {
                        Button(action: {
                            if let url = URL(string: "https://explorer.solana.com/address/\(account.mintAddress)?cluster=\(walletManager.network)") {
                                openURL(url)
                            }
                        }) {
                            Text("🔎 Open Explorer")
                        }
                        Button(action: {
                            if let url = URL(string: "https://github.com/SkatePay/token") {
                                openURL(url)
                            }
                            
                        }) {
                            Text("ℹ️ Open Information")
                        }
                    }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Solana (\(walletManager.network))") {
                    
                    if let address = keychainForSolana.account?.publicKey.base58EncodedString {
                        Text("\(address.prefix(8))...\(address.suffix(8))")
                            .contextMenu {
                                Button(action: {
                                    if let url = URL(string: "https://explorer.solana.com/address/\(address)?cluster=\(walletManager.network)") {
                                        openURL(url)
                                    }
                                }) {
                                    Text("🔎 Open Explorer")
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = address
                                }) {
                                    Text("Copy public key")
                                }
                                
                                Button(action: {
                                    let stringForCopyPaste: String
                                    if let bytes = keychainForSolana.account?.secretKey.bytes {
                                        stringForCopyPaste = "[\(bytes.map { String($0) }.joined(separator: ","))]"
                                    } else {
                                        stringForCopyPaste = "[]"
                                    }
                                    
                                    UIPasteboard.general.string = stringForCopyPaste
                                }) {
                                    Text("Copy secret key")
                                }
                            }
                    } else {
                        Text("Select [🔑 Keys] to start")
                    }
                    
                    NavigationLink {
                        ImportWallet()
                    } label: {
                        Text("🔑 Keys")
                    }
                    NavigationLink {
                        TransferToken(manager: WalletManager())
                    } label: {
                        Text("💾 Transfer")
                    }
                }
                
                assetBalance
                
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
                        if let url = URL(string: ProRobot.HELP_URL_SKATEPAY) {
                            openURL(url)
                        }
                    }
                }
                 
                Button("Disable Wallet") {
                    Task {
                        debugManager.resetDebug()
                        navigation.tab = .settings
                    }
                }
                
                Button("Reset App") {
                    Task {
                        keychainForNostr.clear()
                        keychainForSolana.clear()
                    }
                }
            }
            .navigationTitle("🪪 Wallet")
        }
    }
}

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
