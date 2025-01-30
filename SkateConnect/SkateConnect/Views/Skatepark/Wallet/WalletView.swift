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
    
    @State private var showDropConfirmation = false
    @State private var aliasToDrop: String? = nil

    let saveAction: ()->Void
    
    let keychainForSolana = SolanaKeychainStorage()
        
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
                
                if (!walletManager.getAliasesForCurrentNetwork().isEmpty) {
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
                }
                
                keyPreview

                if (!walletManager.getAliasesForCurrentNetwork().isEmpty) {
                    assetBalance
                }

                Button("Disable Wallet") {
                    Task {
                        debugManager.resetDebug()
                        navigation.tab = .settings
                    }
                }
                
                Button("Purge Keys") {
                    walletManager.purgeAllAccounts()
                }
            }
            .onAppear() {
                walletManager.fetch { isLoading in
                    loading = isLoading
                }
            }
            .navigationTitle("🪪 Wallet")
            .alert("Drop alias?",
                   isPresented: $showDropConfirmation,
                   actions: {
                Button("Cancel", role: .cancel) {}
                Button("Drop", role: .destructive) {
                    if let alias = aliasToDrop {
                        walletManager.removeKey(alias: alias)
                    }
                }
            }, message: {
                Text("Are you sure you want to remove this alias?")
            })
        }
    }
}

// MARK: - UI Components
private extension WalletView {
    var assetBalance: some View {
        Section {
            if loading {
                VStack {
                    ProgressView("Loading assets...")
                        .id(UUID())
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity)
            } else {
                if (walletManager.balance > 0) {
                    NavigationLink {
                        TransferAsset(transferType: .sol)
                            .environmentObject(walletManager)
                    } label: {
                        Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
                    }
                } else {
                    Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
                }

                ForEach(walletManager.accounts) { account in
                    if account.lamports > 0 {
                        NavigationLink {
                            TransferAsset(transferType: .token(account))
                                .environmentObject(walletManager)
                        } label: {
                            Text("\(account.lamports) $\(account.symbol.prefix(3))")
                        }
                        .contextMenu {
                            tokenContextMenu(for: account)
                        }
                    } else {
                        Text("\(account.lamports) $\(account.symbol.prefix(3))")
                            .contextMenu {
                                tokenContextMenu(for: account)
                            }
                    }
                }
            }
        } header: {
            HStack {
                Text("Asset Balance")
                Spacer()
                if (!loading) {
                    Button {
                        loading = true
                        walletManager.fetch { isLoading in
                            loading = isLoading
                        }
                    } label: {
                        Text("🔄")
                    }
                }
            }
        }
    }
    
    var keyPreview : some View {
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
                            
                            Button(action: {
                                   aliasToDrop = walletManager.selectedAlias
                                   showDropConfirmation = true
                               }) {
                                   Text("Drop alias")
                               }
                        }
            }
            
            NavigationLink {
                ImportWallet()
            } label: {
                Text("🔑 Manage Keys")
            }
        }
    }
}

// MARK: - Context Menu Builder
private extension WalletView {
    @ViewBuilder
    func tokenContextMenu(for account: SolanaAccount) -> some View {
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

#Preview {
    WalletView(saveAction: {})
}
