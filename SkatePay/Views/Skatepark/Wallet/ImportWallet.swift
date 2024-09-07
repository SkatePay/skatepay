//
//  ImportWallet.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift

struct ImportWallet: View, EventCreating {
    @Environment(\.openURL) private var openURL

    @State private var showingAlert = false
    
    @State private var privateKey: String = ""
    
    let network: Network = .testnet
    @State private var account: SolanaSwift.KeyPair!
    
    let keychainForSolana = SolanaKeychainStorage()
    
    var interfaceForPublicKey: some View {
        Form {
            Section("publicKey") {
                Text(keychainForSolana.account?.publicKey.base58EncodedString ?? "" )
                    .contextMenu {
                        Button(action: {
                            let address: String
                            if let key = keychainForSolana.account?.publicKey.base58EncodedString {
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
                            UIPasteboard.general.string = keychainForSolana.account?.publicKey.base58EncodedString
                        }) {
                            Text("Copy public key")
                        }
                        
                        Button(action: {
                            let stringForCopyPaste: String
                            if let bytes = keychainForSolana.account?.secretKey.bytes {
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
        }
      }
    
    var interfaceForWalletCreation: some View {
        Form {
            Text("New Wallet")

            Section("Private Key") {
                TextField("Enter key", text: $privateKey)
            }
            
            Button("Import Wallet") {
                Task {
                    if (privateKey.isEmpty) {
                        keychainForSolana.clear()
                        return
                    }
                    var intArray: [Int] = []
                    
                    if (privateKey.count == 88) {
                        intArray = Base58.decode(privateKey).map { Int($0) }
                    } else {
                        let cleanedString = privateKey.dropFirst().dropLast()
                        intArray = cleanedString.split(separator: ",").compactMap { Int($0) }
                    }
                    
                    let data = Data(intArray.map { UInt8($0) })
                    
                    do {
                        account = try SolanaSwift.KeyPair(secretKey: data)
                    } catch {
                        print(error)
                    }
                    do {
                        try keychainForSolana.save(account)
                        showingAlert = true
                    } catch {
                        print(error)
                    }
                }
            }
            .alert("Wallet", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            
            Button("Create Wallet") {
                Task {
                    account = try await KeyPair(network: network)
                    do {
                        try keychainForSolana.save(account)
                        showingAlert = true
                    } catch {
                        print(error)
                    }
                }
            }
            
        }
    }
    
    var body: some View {
        interfaceForPublicKey
        interfaceForWalletCreation
    }
}

#Preview {
    ImportWallet()
}

