//
//  TransferToken.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import SolanaSwift
import SwiftData
import SwiftUI

struct TransferToken: View {
    @Query(filter: #Predicate<Friend> { $0.solanaAddress != ""  }, sort: \Friend.name)
    private var friends: [Friend]
    
    @State private var solanaAddress: String = ""
    @State private var amount = 1
    @State private var showingAlert = false
    
    @Environment(\.openURL) private var openURL
    
    private var walletManager: WalletManager
    
    init(manager: WalletManager) {
        self.walletManager = manager
    }
    
    let keychainForSolana = SolanaKeychainStorage()
    
    @State private var selectedOption = 0
    
    var body: some View {
        List {
            Text("Transfer Token")
            
            /// RECEIVER
            Section("Friend") {
                if (friends.count > 0) {
                    Picker("Friend", selection: $selectedOption) {
                        ForEach(Array(friends.enumerated()), id: \.element.id) { idx, friend in
                            Text(friend.name).tag(idx)
                        }
                    }
                } else {
                    Text("Add Friends in Lobby")
                }
                TextField("Address", text: $solanaAddress)
            }
            
            /// BALANCE
            VStack {
                Text("Token Balance")
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
                    
                    TextField("Amount", value: $amount, format: .number)
                        .multilineTextAlignment(.center)
                    
                    Button("Send") {
                        var address = solanaAddress
                        if (amount <= 0) {
                            print("amount is not valid")
                        } else if (solanaAddress.isEmpty) {
                            let friend = friends[selectedOption]
                            address = friend.solanaAddress
                            
                            Task {
                                do {
                                    if let account = keychainForSolana.account {
                                        let preparedTransaction: PreparedTransaction = try await walletManager.blockchainClient.prepareSendingSPLTokens(
                                            account: account,
                                            mintAddress: WalletManager.SOLANA_MINT_ADDRESS,
                                            tokenProgramId: PublicKey(string: WalletManager.SOLANA_TOKEN_PROGRAM_ID),
                                            decimals: 9,
                                            from: tokenAccount.address,
                                            to: address,
                                            amount: UInt64(amount),
                                            lamportsPerSignature: 5000,
                                            minRentExemption: 0
                                        ).preparedTransaction
                                        
                                        //                                        let result: SimulationResult = try await walletManager.blockchainClient.simulateTransaction(preparedTransaction: preparedTransaction)
                                        //                                        print(result)
                                        //                                        print()
                                        
                                        let transactionId: TransactionID = try await walletManager.blockchainClient.sendTransaction(preparedTransaction: preparedTransaction)
                                        print(transactionId)
                                        showingAlert = true
                                    }
                                    
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    }
                    .alert("Transaction Submitted.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) {
                            //                            walletManager.fetch()
                            print("A")
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
