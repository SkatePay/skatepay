//
//  TransferToken.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import SwiftUI

struct TransferToken: View {
    @State private var publicKey: String = ""
    @State private var amount = 0
    @State private var showingAlert = false
    
    @Environment(\.openURL) private var openURL

    private var walletManager: WalletManager
    
    init(manager: WalletManager) {
        self.walletManager = manager
    }
    
    var assetBalance: some View {
        Section("Asset Balance") {
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
    
    var interfaceForTokenTransfer: some View {
        Form {
            Text("Transfer")
            assetBalance
            Section("Receiver Key") {
                TextField("Enter key", text: $publicKey)
            }
            
            Section("Amount") {
                TextField("Amount", value: $amount, format: .number)
            }
            
            Button("Transfer Token") {
                Task {
                    showingAlert = true
                    if (publicKey.isEmpty) {
                        return
                    }
                }
            }
            .alert("Transfer Submitted.", isPresented: $showingAlert) {
                Button("Ok", role: .cancel) { }
            }
        }
    }
    
    var body: some View {
        interfaceForTokenTransfer
    }
}

#Preview {
    TransferToken(manager: WalletManager())
}
