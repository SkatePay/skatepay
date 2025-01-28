//
//  WalletManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import SwiftUI
import NostrSDK
import SolanaSwift
import Combine

class WalletManager: ObservableObject {
    @Published var network: SolanaSwift.Network = .testnet
    @Published var selectedAlias: String = ""
    @Published var publicKey: String?
    @Published var aliases: [String] = [] // Add this line
    
    let keychainForSolana = SolanaKeychainStorage()
    
    var solanaApiClient: SolanaAPIClient!
    var blockchainClient: BlockchainClient!
    
    @Published var balance: UInt64 = 0
    @Published var blockHeight: UInt64 = 0
    @Published var accounts: [SolanaAccount] = []
    
    init() {
        updateApiClient()
        refreshAliases() // Refresh aliases on initialization
    }
    
    // Refresh the list of aliases
    func refreshAliases() {
        aliases = keychainForSolana.getAliases(for: network)
        
        if let alias = aliases.first {
            selectedAlias = alias
        } else {
            selectedAlias = ""
        }
    }
    
    // Update the API client based on the selected network
    func updateApiClient() {
        let solanaEndpoints: [APIEndPoint] = [
            .init(address: "https://api.mainnet-beta.solana.com", network: .mainnetBeta),
            .init(address: "https://api.testnet.solana.com", network: .testnet),
            .init(address: "https://api.devnet.solana.com", network: .devnet),
        ]
        
        // Set the API client based on the selected network
        solanaApiClient = JSONRPCAPIClient(endpoint: solanaEndpoints.first { $0.network == network }!)
        blockchainClient = BlockchainClient(apiClient: solanaApiClient)
    }
    
    // Fetch account details (balance, block height, etc.)
    func fetch() {
        Task {
            do {
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
                
                // Update the UI on the main thread
                await MainActor.run {
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
        fetch()
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
}
