//
//  WalletManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Combine
import ConnectFramework
import Foundation
import NostrSDK
import SolanaSwift
import SwiftUI
import UIKit

enum AssetType: String, CaseIterable {
    case sol = "SOL"
    case token = "Token"
}

enum AssetSendResult {
    case success(transactionId: String)
    case failure(error: Error)
}

extension UserDefaults {
    var selectedAlias: String {
        get { string(forKey: Keys.selectedAlias) ?? "" }
        set { set(newValue, forKey: Keys.selectedAlias) }
    }
    
    var network: SolanaSwift.Network {
        get {
            if let rawValue = string(forKey: Keys.network),
               let network = SolanaSwift.Network(rawValue: rawValue) {
                return network
            }
            return .testnet // Default value
        }
        set { set(newValue.rawValue, forKey: Keys.network) }
    }
}

class WalletManager: ObservableObject {
    @Published var selectedAlias: String = UserDefaults.standard.selectedAlias {
        didSet {
            UserDefaults.standard.selectedAlias = selectedAlias
        }
    }
    
    @Published var network: SolanaSwift.Network = UserDefaults.standard.network {
        didSet {
            UserDefaults.standard.network = network
        }
    }
    
    @Published var publicKey: String?
    @Published var aliases: [String] = []
    @Published var tokens: [String: TokenMetadata] = [:]
    
    let keychainForSolana = SolanaKeychainStorage()
    
    var solanaApiClient: SolanaAPIClient!
    var blockchainClient: BlockchainClient!
    
    @Published var balance: UInt64 = 0
    @Published var blockHeight: UInt64 = 0
    @Published var accounts: [SolanaAccount] = []
    
    init() {
        updateApiClient()
        refreshAliases()
        getTokenList()
    }
    
    func getSelectedAccount() -> KeyPair? {
        return keychainForSolana.get(alias: selectedAlias)?.keyPair
    }
    
    // Refresh the list of aliases
    func refreshAliases() {
        aliases = keychainForSolana.getAliases(for: network)
        
        if (!aliases.contains(selectedAlias)) {
            if let alias = aliases.first {
                selectedAlias = alias
            } else {
                selectedAlias = ""
            }
        }
    }
    
    // Update the API client based on the selected network
    func updateApiClient() {
        let solanaEndpoints: [APIEndPoint] = [
            .init(address: ConnectFramework.Constants.SOLANA_MAIN.ENDPOINT, network: .mainnetBeta),
            .init(address: ConnectFramework.Constants.SOLANA_TEST.ENDPOINT, network: .testnet),
            .init(address: ConnectFramework.Constants.SOLANA_DEV.ENDPOINT, network: .devnet),
        ]
        
        // Set the API client based on the selected network
        solanaApiClient = JSONRPCAPIClient(endpoint: solanaEndpoints.first { $0.network == network }!)
        blockchainClient = BlockchainClient(apiClient: solanaApiClient)
    }
    
    // Fetch account details (balance, block height, etc.)
    func fetch(onLoadingStateChange: @escaping (Bool) -> Void) {
        Task {
            do {
                await MainActor.run {
                    onLoadingStateChange(true)
                }
                let height = try await solanaApiClient.getBlockHeight()
                
                // Get the public key of the selected alias
                let owner = keychainForSolana.get(alias: selectedAlias)?.keyPair.publicKey.base58EncodedString ?? ""
                
                // Fetch token list and account balances
                let tokenListUrl = Constants.SOLANA_TOKEN_LIST_URL
                let networkManager = URLSession.shared
                let tokenRepository = SolanaTokenListRepository(tokenListSource: SolanaTokenListSourceImpl(url: tokenListUrl, networkManager: networkManager))

                let (amount, (resolved, _)) = try await (
                    solanaApiClient.getBalance(account: owner, commitment: "recent"),
                    solanaApiClient.getAccountBalances(
                        for: owner,
                        withToken2022: true,
                        tokensRepository: tokenRepository,
                        commitment: "confirmed"
                    )
                )

                await MainActor.run {
                    onLoadingStateChange(false)
                    
                    blockHeight = height
                    balance = amount
                    
                    accounts = resolved
                        .compactMap { accountBalance in
                            guard let pubKey = accountBalance.pubkey else { return nil }
                            return SolanaAccount(
                                address: pubKey,
                                lamports: accountBalance.lamports ?? 0,
                                token: accountBalance.token,
                                minRentExemption: accountBalance.minimumBalanceForRentExemption,
                                tokenProgramId: accountBalance.tokenProgramId
                            )
                        }
                }
            } catch {
                print("Error fetching account details: \(error)")
            }
        }
    }
    
    func fetchAccountDetails(completion: @escaping (Result<[SolanaAccount], Error>) -> Void) {
        Task {
            do {
                let height = try await solanaApiClient.getBlockHeight()

                let owner = keychainForSolana.get(alias: selectedAlias)?.keyPair.publicKey.base58EncodedString ?? ""

                let tokenListUrl = Constants.SOLANA_TOKEN_LIST_URL
                let networkManager = URLSession.shared
                let tokenRepository = SolanaTokenListRepository(
                    tokenListSource: SolanaTokenListSourceImpl(url: tokenListUrl, networkManager: networkManager)
                )

                let (amount, (resolved, _)) = try await (
                    solanaApiClient.getBalance(account: owner, commitment: "recent"),
                    solanaApiClient.getAccountBalances(
                        for: owner,
                        withToken2022: true,
                        tokensRepository: tokenRepository,
                        commitment: "confirmed"
                    )
                )

                let accounts = resolved.compactMap { accountBalance -> SolanaAccount? in
                    guard let pubKey = accountBalance.pubkey else { return nil }
                    return SolanaAccount(
                        address: pubKey,
                        lamports: accountBalance.lamports ?? 0,
                        token: accountBalance.token,
                        minRentExemption: accountBalance.minimumBalanceForRentExemption,
                        tokenProgramId: accountBalance.tokenProgramId
                    )
                }

                // Update state on main thread
                await MainActor.run {
                    self.blockHeight = height
                    self.balance = amount
                    self.accounts = accounts
                }

                completion(.success(accounts))

            } catch {
                print("❌ fetchAccountDetails failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // Add a new key pair with an alias and network
    func addKey(alias: String, privateKey: String, network: SolanaSwift.Network) throws {
        guard !alias.isEmpty, !privateKey.isEmpty else {
            throw NSError(domain: "InvalidInput", code: -1, userInfo: [NSLocalizedDescriptionKey: "Alias and private key cannot be empty"])
        }
        
        // Decode the private key and create a KeyPair
        let keyPair = try KeyPair(secretKey: Data(Base58.decode(privateKey)))
        
        // Save the key pair with the prefixed alias and network
        try keychainForSolana.save(alias: alias, account: keyPair, network: network)
        
        // Update the selected alias and fetch account details
        selectedAlias = alias
        self.network = network
        refreshAliases() // Refresh the list of aliases
        updateApiClient()
    }
    
    // Remove a key pair by alias
    func removeKey(alias: String) {
        keychainForSolana.clear(alias: alias)
        
        // If the removed key was the selected one, clear the selected alias
        if selectedAlias == alias {
            selectedAlias = ""
            publicKey = nil
            balance = 0
            accounts = []
        }
        
        refreshAliases() // Refresh the list of aliases
    }
    
    // Get all aliases for the current network
    func getAliasesForCurrentNetwork() -> [String] {
        return keychainForSolana.getAliases(for: network)
    }
    
    // Purge all accounts (clear all keys and reset state)
    func purgeAllAccounts() {
        // Get all aliases and clear each key pair
        let aliases = keychainForSolana.getAllAliases()
        for alias in aliases {
            keychainForSolana.clear(alias: alias)
        }
        
        // Reset the WalletManager state
        selectedAlias = ""
        publicKey = nil
        balance = 0
        blockHeight = 0
        accounts = []
        refreshAliases() // Refresh the list of aliases
    }
    
    func getTokenList() {
        let tokenListUrl = Constants.SOLANA_TOKEN_LIST_URL
        let networkManager = URLSession.shared
        let tokenRepository = SolanaTokenListRepository(
            tokenListSource: SolanaTokenListSourceImpl(
                url: tokenListUrl,
                networkManager: networkManager
            )
        )

        Task {
            do {
                self.tokens = try await tokenRepository.all()
            } catch {
                print("❌ Failed to fetch token list: \(error)")
            }
        }
    }
    
    // Format a number for display (e.g., balance)
    static func formatNumber(_ number: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        
        let numberInBillions = Double(number) / 1_000_000_000.0
        
        if let formattedNumber = formatter.string(from: NSNumber(value: numberInBillions)) {
            return formattedNumber
        } else {
            return "Error formatting number"
        }
    }
    
    func getPublicKey() -> String? {
        return keychainForSolana.get(alias: selectedAlias)?.keyPair.publicKey.base58EncodedString
    }
}


extension WalletManager {    
    func sendAsset(
        type: TransferType,
        to recipientAddress: String,
        amount: UInt64
    ) async -> AssetSendResult {
        do {
            guard let account = getSelectedAccount() else {
                return .failure(error: NSError(domain: "WalletManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No selected account"]))
            }

            let preparedTransaction: PreparedTransaction

            switch type {
            case .sol:
                let minRentExemption = try await solanaApiClient.getMinimumBalanceForRentExemption(dataLength: 0, commitment: "confirmed")

                let feeCalculator = DefaultFeeCalculator(
                    lamportsPerSignature: 5000,
                    minRentExemption: minRentExemption
                )

                let recipientPubKey = try PublicKey(string: recipientAddress)
                let recipientBalance = try await solanaApiClient.getBalance(account: recipientAddress, commitment: "confirmed")

                let totalLamports: UInt64 = recipientBalance == 0 ? amount + minRentExemption : amount

                let instruction = SystemProgram.transferInstruction(
                    from: account.publicKey,
                    to: recipientPubKey,
                    lamports: totalLamports
                )

                preparedTransaction = try await blockchainClient.prepareTransaction(
                    instructions: [instruction],
                    signers: [account],
                    feePayer: account.publicKey,
                    feeCalculator: feeCalculator
                )

            case .token(let tokenAccount):
                preparedTransaction = try await blockchainClient
                    .prepareSendingSPLTokens(
                        account: account,
                        mintAddress: tokenAccount.mintAddress,
                        tokenProgramId: PublicKey(string: tokenAccount.tokenProgramId),
                        decimals: tokenAccount.decimals,
                        from: tokenAccount.address,
                        to: recipientAddress,
                        amount: amount,
                        lamportsPerSignature: 5000,
                        minRentExemption: 0
                    )
                    .preparedTransaction
            }

            let txID = try await blockchainClient.sendTransaction(preparedTransaction: preparedTransaction)
            return .success(transactionId: txID)

        } catch {
            print("❌ Error sending asset: \(error)")
            return .failure(error: error)
        }
    }
}
