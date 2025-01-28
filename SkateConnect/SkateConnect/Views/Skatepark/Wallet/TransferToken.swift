//
//  TransferToken.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import ConnectFramework
import SolanaSwift
import SwiftData
import SwiftUI

struct TransferToken: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var walletManager: WalletManager
    
    @Query(filter: #Predicate<Friend> { $0.solanaAddress != "" }, sort: \Friend.name)
    private var friends: [Friend]
    
    private let keychainForSolana = SolanaKeychainStorage()
    
    @State private var showingAlert = false
    @State private var loading = false
    
    @State private var solanaAddress: String = ""
    @State private var selectedOption = 0
    @State private var transactionId: String = ""
    @State private var amount = 0
    
    var body: some View {
        List {
            transferTokenSection
            recipientSection
            
            if loading {
                Section {
                    VStack {
                        ProgressView("Please wait...")
                            .id(UUID())
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(maxHeight: .infinity)
                }
            } else {
                balanceSection
            }
            
            requestTokensSection
        }
        .alert("Transaction \(self.transactionId.prefix(8)) Submitted.", isPresented: $showingAlert) {
            Button("Ok", role: .cancel) {
                self.walletManager.fetch { isLoading in
                    loading = isLoading 
                }
            }
        }
    }
    
    private var transferTokenSection: some View {
        Section {
            Text("Transfer Token")
        }
    }
    
    private var recipientSection: some View {
        Section("Recipient") {
            if friends.isEmpty {
                Text("Add Friends in Lobby")
            } else {
                Picker("Friend", selection: $selectedOption) {
                    ForEach(Array(friends.enumerated()), id: \.element.id) { idx, friend in
                        Text(friend.name).tag(idx)
                    }
                }
            }
            TextField("Address", text: $solanaAddress)
        }
    }
    
    private var balanceSection: some View {
        Section {
            Text("Token Balance")
            ForEach(walletManager.accounts) { tokenAccount in
                tokenAccountView(tokenAccount: tokenAccount)
            }
        }
    }
    
    private func tokenAccountView(tokenAccount: SolanaAccount) -> some View {
        VStack {
            Text("\(tokenAccount.lamports) $\(tokenAccount.symbol.prefix(3))")
                .contextMenu {
                    Button("🔎 Open Explorer") {
                        if let url = URL(string: "https://explorer.solana.com/address/\(tokenAccount.mintAddress)?cluster=\(walletManager.network)") {
                            openURL(url)
                        }
                    }
                    Button("ℹ️ Open Information") {
                        if let url = URL(string: "https://github.com/SkatePay/token") {
                            openURL(url)
                        }
                    }
                    Button("Copy token address") {
                        UIPasteboard.general.string = tokenAccount.address
                    }
                }
            
            TextField("Amount", value: $amount, formatter: Formatter.clearForZero)
                .multilineTextAlignment(.center)
            
            Button("Submit") {
                sendTokens(to: solanaAddress.isEmpty ? friends[selectedOption].solanaAddress : solanaAddress, tokenAccount: tokenAccount)
            }
            .padding()
        }
    }
    
    private var requestTokensSection: some View {
        Section {
            Button("💁🏻‍♀️ Request Tokens") {
                Task {
                    print("Requesting...")
                }
            }
        }
    }
    
    private func sendTokens(to address: String, tokenAccount: SolanaAccount) {
        guard amount > 0 else {
            print("Amount is not valid")
            return
        }
        
        Task {
            do {
                await MainActor.run {
                    loading = true
                }
                if let account = walletManager.getSelectedAccount() {
                    let preparedTransaction: PreparedTransaction = try await walletManager.blockchainClient.prepareSendingSPLTokens(
                        account: account,
                        mintAddress: Constants.SOLANA_MINT_ADDRESS,
                        tokenProgramId: PublicKey(string: Constants.SOLANA_TOKEN_PROGRAM_ID),
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
                        self.loading = false
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

#Preview {
    TransferToken()
}
