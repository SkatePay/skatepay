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
    @State private var loading = false
    
    var body: some View {
        Form {
            Section("Create New \(walletManager.network) Key") {
                TextField("Alias", text: $newAlias_Create)
                Button("Create") {
                    if !newAlias_Create.isEmpty {
                        Task {
                            if let keyPair = try? await KeyPair(network: walletManager.network) {
                                try? walletManager.keychainForSolana.save(alias: newAlias_Create, account: keyPair, network: walletManager.network)
                                walletManager.selectedAlias = newAlias_Create
                                walletManager.refreshAliases()
                                
                                walletManager.fetch { isLoading in
                                    loading = isLoading
                                }
                                showingAlert = true
                            }
                        }
                    }
                }
                .disabled(newAlias_Create.isEmpty)
                .alert("Key Created.", isPresented: $showingAlert) {
                    Button("Ok", role: .cancel) { }
                }
            }
        }
        
        Form {
            Section("Import Existing Key") {
                TextField("Alias", text: $newAlias_Import)
                TextField("Private Key", text: $privateKey)
                
                Button("Import") {
                    Task{
                        await importWallet()
                    }
                }
                .disabled(newAlias_Import.isEmpty || privateKey.isEmpty)
            }
            .alert("Wallet Imported.", isPresented: $showingAlert) {
                Button("Ok", role: .cancel) { }

            }
        }
    }
    
    func importWallet() async {
        if newAlias_Import.isEmpty || privateKey.isEmpty {
            return
        }

        do {
            var keyPair: KeyPair?

            if isMnemonic(privateKey) {
                let mnemonicArray = privateKey.split(separator: " ").map { String($0) }
                keyPair = try await KeyPair(phrase: mnemonicArray, network: walletManager.network, derivablePath: .default)
            } else {
                var intArray: [Int] = []

                if privateKey.count == 88 {
                    // Base58 Secret Key
                    intArray = Base58.decode(privateKey).map { Int($0) }
                } else {
                    // Byte array input
                    let cleanedString = privateKey.dropFirst().dropLast()
                    intArray = cleanedString.split(separator: ",").compactMap { Int($0) }
                }

                let data = Data(intArray.map { UInt8($0) })
                keyPair = try KeyPair(secretKey: data)
            }

            if let keyPair = keyPair {
                try? walletManager.keychainForSolana.save(alias: newAlias_Import, account: keyPair, network: walletManager.network)
                walletManager.selectedAlias = newAlias_Import
                walletManager.refreshAliases()

                walletManager.fetch { isLoading in
                    loading = isLoading
                }

                showingAlert = true
            }
        } catch {
            print("❌ Error importing wallet: \(error)")
        }
    }
}

func isMnemonic(_ input: String) -> Bool {
    let words = input.split(separator: " ")
    return words.count == 12 || words.count == 24
}

#Preview {
    ImportWallet()
}

