//
//  ImportWallet.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import SwiftUI
import NostrSDK
import SolanaSwift

struct ImportWallet: View {
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var newAlias_Create: String = ""
    @State private var newAlias_Import: String = ""
    @State private var privateKey: String = ""
    
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section("Create \(walletManager.network) Wallet") {
                TextField("Alias", text: $newAlias_Create)
                Button("Create") {
                    if !newAlias_Create.isEmpty {
                        Task {
                            if let keyPair = try? await KeyPair(network: walletManager.network) {
                                try? walletManager.keychainForSolana.save(alias: newAlias_Create, account: keyPair, network: walletManager.network)
                                walletManager.selectedAlias = newAlias_Create
                                walletManager.refreshAliases() // Refresh the list of aliases
                                walletManager.fetch()
                                showingAlert = true
                            }
                        }
                    }
                }
                .alert("Wallet Created.", isPresented: $showingAlert) {
                    Button("Ok", role: .cancel) { }
                }
            }
        }
        
        Form {
            Section("Import Wallet") {
                TextField("Alias", text: $newAlias_Import)
                TextField("Private Key", text: $privateKey)
                
                Button("Import") {
                    if !newAlias_Import.isEmpty && !privateKey.isEmpty {
                        var intArray: [Int] = []

                        if (privateKey.count == 88) {
                            intArray = Base58.decode(privateKey).map { Int($0) }
                        } else {
                            let cleanedString = privateKey.dropFirst().dropLast()
                            intArray = cleanedString.split(separator: ",").compactMap { Int($0) }
                        }

                        let data = Data(intArray.map { UInt8($0) })

                        do {
                            let keyPair = try KeyPair(secretKey: data)
                            try? walletManager.keychainForSolana.save(alias: newAlias_Import, account: keyPair, network: walletManager.network)
                            walletManager.selectedAlias = newAlias_Import
                            walletManager.refreshAliases() // Refresh the list of aliases
                            walletManager.fetch()
                            showingAlert = true
                        } catch {
                            print(error)
                        }
                    }
                }
                .alert("Wallet Imported.", isPresented: $showingAlert) {
                    Button("Ok", role: .cancel) { }
                }
            }
        }
    }
}

#Preview {
    ImportWallet()
}

