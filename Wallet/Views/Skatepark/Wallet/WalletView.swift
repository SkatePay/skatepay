//
//  WalletView.swift
//  Wallet
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

    // Configs
    let accountStorage = KeychainAccountStorage()
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
                let owner = accountStorage.account?.publicKey.base58EncodedString ?? ""
                
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
    
    let accountStorage = KeychainAccountStorage()
    
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
    
    var body: some View {
        NavigationView {
            Form {
                Section ("NOSTR") {
                    Button("🔁 Cycle Keys") {
                        keypair = Keypair()
                        
                        nsec = keypair?.privateKey.nsec ?? ""
                        npub = keypair?.publicKey.npub ?? ""
                        
                        host.privateKey = keypair?.privateKey.hex ?? ""
                        host.publicKey = keypair?.publicKey.hex ?? ""
                        
                        host.nsec = keypair?.privateKey.nsec ?? ""
                        host.npub = keypair?.publicKey.npub ?? ""
                        
                        saveAction()
                    }
                }
                
                Section("npub") {
                    Text(npub ?? host.npub)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = npub ?? host.npub
                            }) {
                                Text("Copy npub")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = solanaClient.publicKey ?? host.publicKey
                            }) {
                                Text("Copy phex")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = nsec ?? host.nsec
                            }) {
                                Text("Copy nsec")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = keypair?.publicKey.hex ?? host.privateKey
                            }) {
                                Text("Copy shex")
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
                }
                
                Section ("Methods") {
                    NavigationLink {
                        ImportWallet()
                    } label: {
                        Text("💼 Wallet")
                    }
                    NavigationLink {
                        TransferToken()
                    } label: {
                        Text("🐟 Tokens")
                    }
                }
                
                Section("publicKey") {
                    Text(accountStorage.account?.publicKey.base58EncodedString ?? "" )
                        .contextMenu {
                            Button(action: {
                                let address: String
                                if let key = accountStorage.account?.publicKey.base58EncodedString {
                                    address = key
                                } else {
                                    address = ""
                                }
                                
                                if let url = URL(string: "https://explorer.solana.com/address/\(address)?cluster=\(network)") {
                                    openURL(url)
                                }
                            }) {
                                Text("Open explorer")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = accountStorage.account?.publicKey.base58EncodedString
                            }) {
                                Text("Copy public key")
                            }
                            
                            Button(action: {
                                let stringForCopyPaste: String
                                if let bytes = accountStorage.account?.secretKey.bytes {
                                    stringForCopyPaste = "[\(bytes.map { String($0) }.joined(separator: ","))]"
                                } else {
                                    stringForCopyPaste = "[]"
                                }
                                
                                UIPasteboard.general.string = stringForCopyPaste
                            }) {
                                Text("Copy secret key")
                            }
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
                            }
                    }
                }
                
                Section("balance") {
                    Text("\(formatNumber(balance)) SOL")
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
        .task {
            fetch()
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
    
    
    func fetch() {
        Task {
            let apiClient = JSONRPCAPIClient(endpoint: solanaEndpoints[1])
            
            blockHeight = try await apiClient.getBlockHeight()
            
            do {
                let account = accountStorage.account?.publicKey.base58EncodedString ?? ""
                balance = try await apiClient.getBalance(account: account, commitment: "recent")
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    WalletView(host: .constant(Host()), saveAction: {})
}
