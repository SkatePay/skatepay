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

class WalletManager: ObservableObject  {
    @Published var network: SolanaSwift.Network = .testnet
    
    @Published var publicKey: String?
    
    let keychainForSolana = SolanaKeychainStorage()
    
    var solanaApiClient: SolanaAPIClient!
    var blockchainClient: BlockchainClient!
    
    @Published var balance: UInt64 = 0
    @Published var blockHeight: UInt64 = 0
    @Published var accounts: [SolanaAccount] = []
    
    init() {
        let solanaEndpoints: [APIEndPoint] = [
            .init(
                address: "https://api.mainnet-beta.solana.com",
                network: .mainnetBeta
            ),
            .init(
                address: "https://api.testnet.solana.com",
                network: .testnet
            ),
            .init(
                address: "https://api.devnet.solana.com",
                network: .devnet
            ),
        ]
        
        solanaApiClient = JSONRPCAPIClient(endpoint: solanaEndpoints[1])
        fetch()
        
        blockchainClient = BlockchainClient(apiClient: solanaApiClient)
    }
    
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
    
    func fetch() {
        Task {
            do {
                let height = try await solanaApiClient.getBlockHeight()
                
                let owner = keychainForSolana.account?.publicKey.base58EncodedString ?? ""
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
                
                // Update model on main thread
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
                print(error)
            }
        }
    }
}
