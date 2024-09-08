//
//  TransferToken.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import SolanaSwift
import SwiftUI

struct TransferToken: View {
    @State private var solanaAddress: String = "Ben8gD6wtxharLvNBWJFE3QZsyy9zuDRFNNzCVF79ENT"
    @State private var amount = 1
    @State private var showingAlert = false
    
    @Environment(\.openURL) private var openURL
    
    private var walletManager: WalletManager
    
    init(manager: WalletManager) {
        self.walletManager = manager
    }
    
    let keychainForSolana = SolanaKeychainStorage()
    
    var body: some View {
        List {
            Text("Transfer")
            
            Section("Receiver") {
                TextField("Address", text: $solanaAddress)
            }
            
            Section("Asset Balance \(walletManager.accounts.count)") {
                ForEach(walletManager.accounts) { tokenAccount in
                    Text("\(tokenAccount.lamports) $\(tokenAccount.symbol.prefix(3))")
                        .contextMenu {
                            Button(action: {
                                if let url = URL(string: "https://explorer.solana.com/address/\(tokenAccount.mintAddress)?cluster=\(walletManager.network)") {
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
                            
                            Button(action: {
                                UIPasteboard.general.string = tokenAccount.address
                            }) {
                                Text("Copy token address")
                            }
                        }
                    
                    Section("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                    }
                    
                    Button("Send") {
                        Task {
                            if (!solanaAddress.isEmpty) {
                                do {
                                    if let account = keychainForSolana.account {
                                        let preparedTransaction: PreparedTransaction = try await walletManager.blockchainClient.prepareSendingSPLTokens(
                                            account: account,
                                            mintAddress: WalletManager.SOLANA_MINT_ADDRESS,
                                            tokenProgramId: PublicKey(string: WalletManager.SOLANA_TOKEN_PROGRAM_ID),
                                            decimals: 9,
                                            from: tokenAccount.address,
                                            to: solanaAddress,
                                            amount: UInt64(amount),
                                            lamportsPerSignature: 5000,
                                            minRentExemption: 0
                                        ).preparedTransaction
                                        
//                                        let result: SimulationResult = try await walletManager.blockchainClient.simulateTransaction(preparedTransaction: preparedTransaction)
//                                        print(result)
//                                        print()
                                        
                                        let transactionId: TransactionID = try await walletManager.blockchainClient.sendTransaction(preparedTransaction: preparedTransaction)
                                        print(transactionId)
                                    }
                                    
                                } catch {
                                    print(error)
                                }
                            }
                            showingAlert = true
                        }
                    }
                    .alert("Transfer Submitted.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) {
//                            walletManager.fetch()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TransferToken(manager: WalletManager())
}
