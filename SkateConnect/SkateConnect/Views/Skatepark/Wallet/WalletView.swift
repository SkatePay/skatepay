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
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var loading = false

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
            NavigationLink {
                TransferToken()
                    .environmentObject(walletManager)
            } label: {
                Text("💾 Transfer")
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
                         walletManager.fetch { isLoading in
                            loading = isLoading
                         }
                     }
                 }
                
                Section("Select Account") {
                    Picker("Alias", selection: $walletManager.selectedAlias) {
                        ForEach(walletManager.aliases, id: \.self) { alias in
                            Text(alias).tag(alias)
                        }
                    }
                    .onChange(of: walletManager.selectedAlias) {
                        walletManager.updateApiClient()
                        walletManager.refreshAliases()
                        walletManager.fetch { isLoading in
                            loading = isLoading
                         }
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
                }
                
                if loading {
                    Section {
                        VStack {
                            ProgressView("Loading assets...")
                                .id(UUID())
                                .padding()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    assetBalance
                }
                
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
            .onAppear() {
                walletManager.fetch { isLoading in
                    loading = isLoading
                }
            }
            .navigationTitle("🪪 Wallet")
        }
    }
}

#Preview {
    WalletView(saveAction: {})
}
