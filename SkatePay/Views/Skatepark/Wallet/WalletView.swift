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

class SolanaClient: ObservableObject  {
    @Published var network: Network = .testnet
    
    @Published var publicKey: String?
    
    let keychainForSolana = SolanaKeychainStorage()
    
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
    var apiClient: SolanaAPIClient!
    
    // Reponses
    @Published var balance: UInt64 = 0
    @Published var blockHeight: UInt64 = 0
    @Published var accounts: [SolanaAccount] = []
    
    init() {
        apiClient = JSONRPCAPIClient(endpoint: solanaEndpoints[1])
        fetch()
    }
    
    func fetch() {
        Task {
            blockHeight = try await apiClient.getBlockHeight()
            
            do {
                let owner = keychainForSolana.account?.publicKey.base58EncodedString ?? ""
                
                //                let mint = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
                //                let programId = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
                
                let tokenListUrl = "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
                
                let networkManager = URLSession.shared
                let tokenRepository = SolanaTokenListRepository(tokenListSource: SolanaTokenListSourceImpl(url: tokenListUrl, networkManager: networkManager))
                
                
                let (amount, (resolved, _)) = try await(
                    apiClient.getBalance(account: owner, commitment: "recent"),
                    apiClient.getAccountBalances(
                        for: owner,
                        withToken2022: true,
                        tokensRepository: tokenRepository,
                        commitment: "confirmed"
                    )
                )
                
                balance = amount
                accounts = resolved
                    .map { accountBalance in
                        guard let pubKey = accountBalance.pubkey else {
                            return nil
                        }
                        
                        return SolanaAccount(
                            address: pubKey,
                            lamports: accountBalance.lamports ?? 0,
                            token: accountBalance.token,
                            minRentExemption: accountBalance.minimumBalanceForRentExemption,
                            tokenProgramId: accountBalance.tokenProgramId
                        )
                    }
                    .compactMap { $0 }
            } catch {
                print(error)
            }
        }
    }
}

struct WalletView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var host: Host
    
    @StateObject private var solanaClient = SolanaClient()
    
    // Nostr
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    let saveAction: ()->Void
    
    @Environment(\.openURL) private var openURL
    
    var network: Network = .testnet
    
    let keychainForSolana = SolanaKeychainStorage()
    let keychainForNostr = NostrKeychainStorage()
    
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
                    Text("🌐 \(network)")
                        .contextMenu {
                            Button(action: {
                                if let url = URL(string: "https://explorer.solana.com/?cluster=\(network)") {
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
                        TransferToken()
                    } label: {
                        Text("💾 Actions")
                    }
                }
                
                // Asset Balance
                Section("Asset Balance") {
                    Text("\(formatNumber(solanaClient.balance)) SOL")
                    ForEach(solanaClient.accounts) { account in
                        Text("\(account.lamports) $\(account.symbol.prefix(3))")
                            .contextMenu {
                                Button(action: {
                                    if let url = URL(string: "https://explorer.solana.com/address/\(account.mintAddress)?cluster=\(network)") {
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
                                NavigationLink {
                                    TransferToken()
                                } label: {
                                    Text("💾 Methods")
                                }
                            }
                    }
                }
                
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
    
    func formatNumber(_ number: UInt64) -> String {
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

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
