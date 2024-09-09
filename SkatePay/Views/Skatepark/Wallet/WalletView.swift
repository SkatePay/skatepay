//
//  SkatePayView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift
import Combine


class WalletManager: ObservableObject  {
    public static let SOLANA_MINT_ADDRESS = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
    public static let SOLANA_TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    public static let SOLANA_TOKEN_LIST_URL = "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"

    @Published var network: Network = .testnet
    
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
                let tokenListUrl = WalletManager.SOLANA_TOKEN_LIST_URL
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

struct WalletView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var host: Host
    
    @StateObject private var walletManager = WalletManager()
    
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    let saveAction: ()->Void
    
    @Environment(\.openURL) private var openURL
        
    let keychainForSolana = SolanaKeychainStorage()
    let keychainForNostr = NostrKeychainStorage()
    
    var assetBalance: some View {
        Section("Asset Balance") {
            Text("\(WalletManager.formatNumber(walletManager.balance)) SOL")
            ForEach(walletManager.accounts) { account in
                Text("\(account.lamports) $\(account.symbol.prefix(3))")
                    .contextMenu {
                        Button(action: {
                            if let url = URL(string: "https://explorer.solana.com/address/\(account.mintAddress)?cluster=\(walletManager.network)") {
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
                    }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section ("NOSTR") {
                    Button("🔁 Cycle Keys") {
                        Task {
                            keypair = Keypair()
                            
                            let keypair = Keypair()!
                            try keychainForNostr.save(keypair)
                            
                            saveAction()
                        }
                    }
                }
                
                Section("npub") {                    
                    Text(keychainForNostr.account?.publicKey.npub ?? "No npub available")
                        .contextMenu {
                            if let npub = keychainForNostr.account?.publicKey.npub {
                                Button(action: {
                                    UIPasteboard.general.string = npub
                                }) {
                                    Text("Copy npub")
                                }
                            }
                            
                            if let phex = keychainForNostr.account?.publicKey.hex {
                                Button(action: {
                                    UIPasteboard.general.string = phex
                                }) {
                                    Text("Copy phex")
                                }
                            }
                            
                            if let nsec = keychainForNostr.account?.privateKey.nsec {
                                Button(action: {
                                    UIPasteboard.general.string = nsec
                                }) {
                                    Text("Copy nsec")
                                }
                            }
                            
                            if let shex = keychainForNostr.account?.privateKey.hex {
                                Button(action: {
                                    UIPasteboard.general.string = shex
                                }) {
                                    Text("Copy shex")
                                }
                            }
                        }
                }
                
                Section("Solana") {
                    Text("🌐 \(walletManager.network)")
                        .contextMenu {
                            Button(action: {
                                if let url = URL(string: "https://explorer.solana.com/?cluster=\(walletManager.network)") {
                                    openURL(url)
                                }
                                
                            }) {
                                Text("Open explorer")
                            }
                        }
                    NavigationLink {
                        ImportWallet()
                    } label: {
                        Text("💼 Wallet")
                    }
                    NavigationLink {
                        TransferToken(manager: WalletManager())
                    } label: {
                        Text("💾 Methods")
                    }
                }
                
                assetBalance
                
                Button("💁 Request Token Reward") {
                    Task {
                        print("Requesting...")
                    }
                }
                
                Button("💁🏻‍♀️ Get Help") {
                    Task {
                        if let url = URL(string: "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics") {
                            openURL(url)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
