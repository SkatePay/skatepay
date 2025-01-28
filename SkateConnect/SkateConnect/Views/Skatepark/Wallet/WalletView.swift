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
    @Environment(\.openURL) private var openURL

    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    
    @Binding var host: Host
    
    @StateObject private var walletManager = WalletManager()
    
    @State private var keypair: Keypair?
    
    let saveAction: ()->Void
    
    let keychainForSolana = SolanaKeychainStorage()
        
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
                
                Button("Disable Wallet") {
                    Task {
                        debugManager.resetDebug()
                        navigation.tab = .settings
                    }
                }
                
                Button("Reset Wallet") {
                    Task {
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
