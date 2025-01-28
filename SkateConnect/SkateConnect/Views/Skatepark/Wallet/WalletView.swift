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
    @EnvironmentObject var walletManager: WalletManager

    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    
    @Binding var host: Host
        
    @State private var keypair: Keypair?
    
    @State private var keyAlias: String = ""
    @State private var newAlias: String = ""
    @State private var newPrivateKey: String = ""
    
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
                Section("Network") {
                     Picker("Network", selection: $walletManager.network) {
                         Text("Mainnet").tag(SolanaSwift.Network.mainnetBeta)
                         Text("Testnet").tag(SolanaSwift.Network.testnet)
                     }
                     .onChange(of: walletManager.network) {
                         walletManager.updateApiClient()
                         walletManager.refreshAliases()
                         walletManager.fetch()
                     }
                 }
                
                Section("Select Account") {
                    Picker("Alias", selection: $keyAlias) {
                        ForEach(walletManager.aliases, id: \.self) { alias in
                            Text(alias).tag(alias)
                        }
                    }
                    .onChange(of: keyAlias) {
                        walletManager.selectedAlias = keyAlias
                        walletManager.fetch()
                    }
                }

                
                Section("Solana (\(walletManager.network))") {
                    
                    if let account = keychainForSolana.get(alias: walletManager.selectedAlias)?.keyPair {
                        let address = account.publicKey.base58EncodedString
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
                                        let bytes = account.secretKey.bytes
                                        stringForCopyPaste = "[\(bytes.map { String($0) }.joined(separator: ","))]"
                                        
                                        UIPasteboard.general.string = stringForCopyPaste
                                    }) {
                                        Text("Copy secret key")
                                    }
                                }
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
                
                Button("Purge All Accounts") {
                    walletManager.purgeAllAccounts()
                }
            }
            .navigationTitle("🪪 Wallet")
        }
    }
}

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
