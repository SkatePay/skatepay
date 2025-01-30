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

struct TransferAsset: View {
    enum TransferType: Equatable {
        case sol
        case token(SolanaAccount)
    }

    enum RecipientMode {
        case friend
        case manual
    }

    @Environment(\.openURL) private var openURL
    @EnvironmentObject var walletManager: WalletManager

    @Query(sort: \Friend.name)
    private var allFriends: [Friend]

    @State private var showingAlert = false
    @State private var loading = false
    @State private var alertMessage: String = ""

    // Recipient state
    @State private var selectedFriend: Friend?
    @State private var selectedCryptoAddress: CryptoAddress?
    @State private var recipientMode: RecipientMode = .friend

    @State private var solanaAddress: String = ""
    @State private var transactionId: String = ""
    @State private var amount = 0

    let transferType: TransferType

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
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(transactionId.isEmpty ? "Error" : "Success"),
                message: Text(transactionId.isEmpty ? alertMessage : "Transaction \(transactionId.prefix(8)) Submitted."),
                dismissButton: .default(Text("OK")) {
                    if !transactionId.isEmpty {
                        walletManager.fetch { isLoading in
                            loading = isLoading
                        }
                    }
                }
            )
        }
        .onAppear {
            let filteredFriends = allFriends.filter {
                $0.cryptoAddresses.contains { $0.network == walletManager.network.stringValue }
            }
            guard !filteredFriends.isEmpty else { return }

            if selectedFriend == nil {
                let firstFriend = filteredFriends[0]
                selectedFriend = firstFriend

                let addresses = firstFriend.cryptoAddresses.filter {
                    $0.network == walletManager.network.stringValue
                }
                if let firstAddress = addresses.first {
                    selectedCryptoAddress = firstAddress
                }
            }
        }
    }
}

// MARK: - Subviews

private extension TransferAsset {
    var transferTokenSection: some View {
        Section {
            Text("Transfer \(transferType == .sol ? "SOL" : "Token") on \(walletManager.network)")
        }
    }
    
    var recipientSection: some View {
        Section("Recipient") {
            // Toggle between manual entry and friend selection
            Picker("Recipient Mode", selection: $recipientMode) {
                Text("Select from Friends").tag(RecipientMode.friend)
                Text("Enter Address Manually").tag(RecipientMode.manual)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 8)

            if recipientMode == .friend {
                // Friend selection and address picker
                let filteredFriends = allFriends.filter { friend in
                    friend.cryptoAddresses.contains { $0.network == walletManager.network.stringValue }
                }

                if filteredFriends.isEmpty {
                    Text("Add Crypto Friends in Lobby")
                } else {
                    // Friend picker
                    Picker("Friend", selection: $selectedFriend) {
                        ForEach(filteredFriends, id: \.self) { friend in
                            Text(friend.name)
                                .tag(Optional(friend))
                        }
                    }
                    .onChange(of: selectedFriend) {
                        guard let newFriend = selectedFriend else {
                            selectedCryptoAddress = nil
                            return
                        }
                        let addresses = newFriend.cryptoAddresses.filter {
                            $0.network == walletManager.network.stringValue
                        }
                        selectedCryptoAddress = addresses.first
                    }

                    // Address picker for the selected friend
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
                        }
                    }
                }
            } else {
                // Manual address input
                TextField("Enter Solana Address", text: $solanaAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: solanaAddress) {
                        // Clear the selected friend and address when manually entering an address
                        selectedFriend = nil
                        selectedCryptoAddress = nil
                    }
            }
        }
    }
    
    var balanceSection: some View {
        Section {
            switch transferType {
            case .sol:
                Text("SOL Balance: \(walletManager.balance)")
            case .token(let tokenAccount):
                Text("\(tokenAccount.lamports) $\(tokenAccount.symbol.prefix(3))")
            }

            TextField("Amount", value: $amount, formatter: Formatter.clearForZero)

            HStack {
                Spacer()
                Button("Submit") {
                    validateAndSendAsset()
                }
                Spacer()
            }
            .padding()
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
private extension TransferAsset {
    func validateAndSendAsset() {
        let recipientAddress: String
        if recipientMode == .friend, let selectedAddress = selectedCryptoAddress?.address {
            recipientAddress = selectedAddress
        } else {
            recipientAddress = solanaAddress
        }

        // Validation
        if recipientAddress.isEmpty {
            alertMessage = "Please enter a valid recipient address."
            showingAlert = true
            return
        }

        if amount <= 0 {
            alertMessage = "Amount must be greater than zero."
            showingAlert = true
            return
        }

        sendAsset(to: recipientAddress)
    }

    func sendAsset(to address: String) {
        Task {
            do {
                await MainActor.run { loading = true }

                guard let account = walletManager.getSelectedAccount() else {
                    throw URLError(.badServerResponse)
                }

                let preparedTransaction: PreparedTransaction
                switch transferType {
                case .sol:
                    let dataLength = 0 // 165 bytes for a token account
                    let minRentExemption = try await walletManager.solanaApiClient.getMinimumBalanceForRentExemption(dataLength: 0, commitment: "confirmed")

                    let feeCalculator = DefaultFeeCalculator(
                        lamportsPerSignature: 5000,
                        minRentExemption: minRentExemption
                    )
                    
                    let recipientAddress = try PublicKey(string: address)

                    let amountInLamports = UInt64(amount) // Amount of SOL to send (in lamports)
                    let rentExemption = minRentExemption // Rent exemption for the recipient's account

                    // Check if the recipient's account exists
                    let recipientBalance = try await walletManager.solanaApiClient.getBalance(account: address, commitment: "confirmed")

                    let totalLamports: UInt64
                    if recipientBalance == 0 {
                        // Recipient's account does not exist; include rent exemption
                        totalLamports = amountInLamports + rentExemption
                    } else {
                        // Recipient's account exists; send only the amount
                        totalLamports = amountInLamports
                    }

                    // Create the transfer instruction
                    let instruction = SystemProgram.transferInstruction(
                        from: account.publicKey,
                        to: recipientAddress,
                        lamports: totalLamports
                    )

                    // Prepare and send the transaction
                    preparedTransaction = try await walletManager.blockchainClient.prepareTransaction(
                        instructions: [instruction],
                        signers: [account],
                        feePayer: account.publicKey,
                        feeCalculator: feeCalculator
                    )
                case .token(let tokenAccount):
                    preparedTransaction = try await walletManager.blockchainClient
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
                }

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
                await MainActor.run {
                    loading = false
                    alertMessage = "Failed to send transaction. Please try again."
                    showingAlert = true
                }
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
    TransferAsset(transferType: .sol)
}
