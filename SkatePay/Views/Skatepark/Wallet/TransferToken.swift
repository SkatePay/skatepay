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
    @Environment(\.openURL) private var openURL
    
    @Query(filter: #Predicate<Friend> { $0.solanaAddress != ""  }, sort: \Friend.name)
    private var friends: [Friend]
    
    let keychainForSolana = SolanaKeychainStorage()
    
    @State private var showingAlert = false
    
    @State private var solanaAddress: String = ""
    @State private var selectedOption = 0
    
    @State private var transactionId: String = ""
    
    @State private var amount = 0
    
    private var walletManager: WalletManager
    
    init(manager: WalletManager) {
        self.walletManager = manager
    }
    
    var body: some View {
        List {
            Text("Transfer Token")
            
            /// RECEIVER
            Section("Recipient") {
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
                    
                    TextField("Amount", value: $amount, formatter: Formatter.clearForZero)
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
                                            mintAddress: SkatePayApp.SOLANA_MINT_ADDRESS,
                                            tokenProgramId: PublicKey(string: SkatePayApp.SOLANA_TOKEN_PROGRAM_ID),
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
                                        
                                        DispatchQueue.main.async {
                                            self.showingAlert = true
                                            self.transactionId = transactionId
                                        }
                                    }
                                    
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    }
                    .padding()
                    .alert("Transaction \(self.transactionId.prefix(8)) Submitted.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) {
                        }
                    }
                }
            }
            
            Section {
                Button("💁🏻‍♀️ Request Tokens") {
                    Task {
                        print("Requesting...")
                    }
                }
            }
        }
    }
}

#Preview {
    TransferToken(manager: WalletManager())
}
