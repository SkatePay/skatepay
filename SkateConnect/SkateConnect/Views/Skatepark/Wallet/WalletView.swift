//
//  WalletView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import ConnectFramework
import SwiftUI
import NostrSDK
import SolanaSwift

struct WalletView: View {
    @Environment(\.openURL) private var openURL

    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var loading = false
    @State private var error: Error?
    
    @State private var showDropConfirmation = false
    @State private var showPurgeConfirmation = false
    @State private var aliasToDrop: String? = nil

    let saveAction: ()->Void
    
    let keychainForSolana = SolanaKeychainStorage()
        
    var body: some View {
        List {
            Section("Network") {
                 Picker("Network", selection: $walletManager.network) {
                     Text("Testnet").tag(SolanaSwift.Network.testnet)
                     Text("Mainnet").tag(SolanaSwift.Network.mainnetBeta)
                 }
                 .onChange(of: walletManager.network) {
                     walletManager.updateApiClient()
                     walletManager.refreshAliases()
                     walletManager.fetch { isLoading, error in
                         self.loading = isLoading
                         self.error = error
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
                        walletManager.fetch { isLoading, error in
                            self.loading = isLoading
                            self.error = error
                        }
                    }
                }
            }
            
            keyPreview

            if (!walletManager.getAliasesForCurrentNetwork().isEmpty) {
                assetBalance
            }
            
            Button("Purge Keys") {
                showPurgeConfirmation = true
            }
            Button("Information") {
                Task {
                    if let url = URL(string: ProRobot.HELP_URL_SOLANA) {
                        openURL(url)
                    }
                }
            }
        }
        .onAppear() {
            walletManager.fetch { isLoading, error in
                self.loading = isLoading
                self.error = error
            }
        }
        .alert("Purge keys?",
               isPresented: $showPurgeConfirmation,
               actions: {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                walletManager.purgeAllAccounts()
            }
        }, message: {
            Text("Are you sure you want to purge your keys?")
        })
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
                if let error = error?.localizedDescription {
                    Text(error)
                } else {
                    if (walletManager.balance > 0) {
                        Button(action: {
                            navigation.path.append(NavigationPathType.transferAsset(transferType: .sol))
                        }) {
                            Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
                        }
                    } else {
                        Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
                    }
                    
                    ForEach(walletManager.accounts) { account in
                        if account.lamports > 0 {
                            let quantity = Double(account.lamports) / pow(10, Double(account.decimals))
                            Button(action: {
                                navigation.path.append(NavigationPathType.transferAsset(transferType: .token(account)))
                            }) {
                                Text("\(quantity) $\(account.symbol.prefix(3))")
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
            }
        } header: {
            HStack {
                Text("Asset Balance")
                Spacer()
                if (!loading) {
                    Button {
                        loading = true
                        walletManager.fetch { isLoading, error in
                            self.loading = isLoading
                            self.error = error
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
                                   Text("Delete Key")
                               }
                        }
            }
            
            Button(action: {
                navigation.path.append(NavigationPathType.importWallet)
            }) {
                let isEmpty = walletManager.getAliasesForCurrentNetwork().isEmpty
                Text(isEmpty ? "🔐 New Account" : "🔑 Manage Keys")
            }
        }
    }
}

// MARK: - Context Menu Builder
private extension WalletView {
    @ViewBuilder
    func tokenContextMenu(for account: SolanaAccount) -> some View {
        Button(action: {
            if let url = URL(string: Constants.SOLANA_MAIN.RABOTA_INFORMATION_URL) {
                openURL(url)
            }
        }) {
            Text("ℹ️ Open Information")
        }
        
        Button(action: {
            if let url = URL(string: "https://solscan.io/address/\(account.address)?cluster=\(walletManager.network)") {
                openURL(url)
            }
        }) {
            Text("🔎 Address Activity")
        }
        
        Button(action: {
            if let url = URL(string: "https://solscan.io/token/\(account.mintAddress)?cluster=\(walletManager.network)") {
                openURL(url)
            }
        }) {
            Text("🔎 Mint Activity")
        }
        
        Button(action: {
            UIPasteboard.general.string = account.mintAddress
        }) {
            Text("Copy Mint Address")
        }
    }
}

#Preview {
    WalletView(saveAction: {})
}
