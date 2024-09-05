//
//  ImportWallet.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift

struct ImportWallet: View, EventCreating {
    @State private var showingAlert = false
    
    @State private var privateKey: String = ""
    
    let network: Network = .devnet
    @State private var account: SolanaSwift.KeyPair!
    
    let accountStorage = KeychainAccountStorage()
    
    var body: some View {
        Text("Import Wallet")
        Form {
            Section("Private Key") {
                TextField("Enter key.", text: $privateKey)
            }
            
            Button("Import Wallet") {
                if (privateKey.isEmpty) {
                    accountStorage.clear()
                    return
                }
                
                let cleanedString = privateKey.dropFirst().dropLast()
                
                let intArray: [Int] = cleanedString.split(separator: ",").compactMap { Int($0) }
                
                let data = Data(intArray.map { UInt8($0) })
                
                do {
                    let account = try SolanaSwift.KeyPair(secretKey: data)
                    print(account.publicKey)
                    
                    try accountStorage.save(account)
                    
                    showingAlert = true
                } catch {
                    print(error)
                }
            }
            .alert("Wallet", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            
            Button("Create Wallet") {
                Task {
                    account = try await KeyPair(network: network)
                    do {
                        try accountStorage.save(account)
                        showingAlert = true
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
}

#Preview {
    ImportWallet()
}

