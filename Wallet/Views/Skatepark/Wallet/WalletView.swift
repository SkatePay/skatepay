//
//  WalletView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift

struct WalletView: View {
    @Environment(\.scenePhase) private var scenePhase

    @Binding var host: Host
    
    // Nostr
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    // Solana
    @State private var publicKey: String?
    @State private var balance: UInt64 = 0
    @State private var blockHeight: UInt64 = 0

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
                Button {
                    if let url = URL(string: "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics") {
                        openURL(url)
                    }
                } label: {
                    Label("Get Help", systemImage: "person.fill.questionmark")
                }
                
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
                                UIPasteboard.general.string = publicKey ?? host.publicKey
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
                    Text("\(network)")
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
                }
                
                Section("publicKey") {
                    Text(accountStorage.account?.publicKey.base58EncodedString ?? "" )
                        .contextMenu {
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
                
                Section("balance") {
                    Text("\(formatNumber(balance)) SOL")
                }
                
                Button("💁 Request Token Reward") {
                    Task {
                        print("Requesting...")
                    }
                }
                
            }
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
        
        if let formattedNumber = formatter.string(from: NSNumber(value: number/1000000000)) {
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
