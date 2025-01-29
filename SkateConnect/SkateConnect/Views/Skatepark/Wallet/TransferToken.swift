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

    @Query(sort: \Friend.name)
    private var allFriends: [Friend]

    @State private var showingAlert = false
    @State private var loading = false

    // Recipient state
    @State private var selectedFriend: Friend?
    @State private var selectedCryptoAddress: CryptoAddress?

    @State private var solanaAddress: String = ""
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
                }
            } else {
                balanceSection
            }

            requestTokensSection
        }
        .alert("Transaction \(transactionId.prefix(8)) Submitted.", isPresented: $showingAlert) {
            Button("Ok", role: .cancel) {
                walletManager.fetch { isLoading in
                    loading = isLoading
                }
            }
        }
        // Auto-select the first friend and address on load
        .onAppear {
            let filteredFriends = allFriends.filter {
                $0.cryptoAddresses.contains { $0.network == walletManager.network.stringValue }
            }
            guard !filteredFriends.isEmpty else { return }

            // If no friend is currently selected, pick the first
            if selectedFriend == nil {
                let firstFriend = filteredFriends[0]
                selectedFriend = firstFriend

                // Also pick the friend's first address on the network
                let addresses = firstFriend.cryptoAddresses.filter {
                    $0.network == walletManager.network.stringValue
                }
                if let firstAddress = addresses.first {
                    selectedCryptoAddress = firstAddress
                    solanaAddress = firstAddress.address
                }
            }
        }
    }
}

// MARK: - Subviews

private extension TransferToken {
    var transferTokenSection: some View {
        Section {
            Text("Transfer Token on \(walletManager.network)")
        }
    }
    
    var recipientSection: some View {
        Section("Recipient") {
            // Filter to those friends that have at least one matching address for the current network
            let filteredFriends = allFriends.filter { friend in
                friend.cryptoAddresses.contains { $0.network == walletManager.network.stringValue }
            }
            
            if filteredFriends.isEmpty {
                Text("Add Crypto Friends in Lobby")
            } else {
                // 1) Friend picker
                Picker("Friend", selection: $selectedFriend) {
                    ForEach(filteredFriends, id: \.self) { friend in
                        Text(friend.name)
                            .tag(Optional(friend))
                    }
                }
                .onChange(of: selectedFriend) {
                    guard let newFriend = selectedFriend else {
                        // If user clears the friend, reset
                        selectedCryptoAddress = nil
                        solanaAddress = ""
                        return
                    }
                    // Grab all addresses on the current network
                    let addresses = newFriend.cryptoAddresses.filter {
                        $0.network == walletManager.network.stringValue
                    }
                    // Automatically select the first address if available
                    if let firstAddress = addresses.first {
                        selectedCryptoAddress = firstAddress
                        solanaAddress = firstAddress.address
                    } else {
                        selectedCryptoAddress = nil
                        solanaAddress = ""
                    } 
                }
                
                // 2) Address picker if the selected friend has multiple addresses
                if let friend = selectedFriend {
                    let matchingAddresses = friend.cryptoAddresses.filter {
                        $0.network == walletManager.network.stringValue
                    }
                    if !matchingAddresses.isEmpty {
                        Picker("Address", selection: $selectedCryptoAddress) {
                            ForEach(matchingAddresses, id: \.self) { addr in
                                Text("\(addr.address.prefix(8))...\(addr.address.suffix(8))")
                                    .tag(Optional(addr))
                            }
                        }
                        .onChange(of: selectedCryptoAddress) {
                            solanaAddress = selectedCryptoAddress?.address ?? ""
                        }
                    }
                }
                
                // 3) Manual override text field
                TextField("Address", text: $solanaAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
    
    var balanceSection: some View {
        Section {
            Text("Token Balance")
            ForEach(walletManager.accounts) { tokenAccount in
                VStack {
                    // Show token balance & context menu
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
                    
                    // Amount to send
                    TextField("Amount", value: $amount, formatter: Formatter.clearForZero)
                        .multilineTextAlignment(.center)
                    
                    // Submit button
                    Button("Submit") {
                        sendTokens(to: solanaAddress, tokenAccount: tokenAccount)
                    }
                    .padding()
                }
            }
        }
    }
    
    var requestTokensSection: some View {
        Section {
            Button("💁🏻‍♀️ Request Tokens") {
                Task {
                    print("Requesting...")
                }
            }
        }
    }
}

// MARK: - Actions

private extension TransferToken {
    func sendTokens(to address: String, tokenAccount: SolanaAccount) {
        guard amount > 0 else {
            print("Amount must be greater than zero.")
            return
        }

        Task {
            do {
                await MainActor.run { loading = true }

                guard let account = walletManager.getSelectedAccount() else {
                    throw URLError(.badServerResponse)
                }

                let preparedTransaction: PreparedTransaction = try await walletManager.blockchainClient
                    .prepareSendingSPLTokens(
                        account: account,
                        mintAddress: Constants.SOLANA_MINT_ADDRESS,
                        tokenProgramId: PublicKey(string: Constants.SOLANA_TOKEN_PROGRAM_ID),
                        decimals: 9,
                        from: tokenAccount.address,
                        to: address,
                        amount: UInt64(amount),
                        lamportsPerSignature: 5000,
                        minRentExemption: 0
                    )
                    .preparedTransaction

                let txID = try await walletManager.blockchainClient.sendTransaction(
                    preparedTransaction: preparedTransaction
                )

                await MainActor.run {
                    loading = false
                    showingAlert = true
                    transactionId = txID
                }
            } catch {
                print("Error sending tokens:", error)
                await MainActor.run { loading = false }
            }
        }
    }
}

// MARK: - Helper
extension SolanaSwift.Network {
    var stringValue: String {
        switch self {
        case .mainnetBeta: return "mainnet-beta"
        case .testnet:     return "testnet"
        case .devnet:      return "devnet"
        }
    }
}

#Preview {
    TransferToken()
}
