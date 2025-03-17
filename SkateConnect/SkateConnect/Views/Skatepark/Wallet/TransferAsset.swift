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

enum TransferType: Equatable, Hashable {
    case sol
    case token(SolanaAccount)
}

enum RecipientMode {
    case friend
    case manual
}

struct TransferAsset: View {
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
                            Text(friend.note.isEmpty ? friend.name : friend.note)
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
                Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
            case .token(let tokenAccount):
                let quantity = Double(tokenAccount.lamports) / pow(10, Double(tokenAccount.decimals))
                Text("\(quantity) $\(tokenAccount.symbol.prefix(3))")
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
            await MainActor.run { loading = true }

            let result = await walletManager.sendAsset(
                type: transferType,
                to: address,
                amount: UInt64(amount)
            )

            await MainActor.run {
                loading = false
                switch result {
                case .success(let txId):
                    transactionId = txId
                    showingAlert = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
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
