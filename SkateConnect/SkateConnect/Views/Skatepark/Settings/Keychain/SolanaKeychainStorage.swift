//
//  SolanaKeychainStorage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import SolanaSwift
import KeychainSwift
import Foundation

struct SolanaKeychainStorage {
    let keychain = KeychainSwift()
    let keyPrefix = "SOLANA_KEYPAIR_"
    
    // Struct to store both the KeyPair and the network
    struct WalletData: Codable {
        let keyPair: KeyPair
        let network: SolanaSwift.Network
    }
    
    // Save a key pair with an alias and network
    func save(alias: String, account: KeyPair, network: SolanaSwift.Network) throws {
        let prefixedAlias = keyPrefix + alias
        let walletData = WalletData(keyPair: account, network: network)
        let data = try JSONEncoder().encode(walletData)
        keychain.set(data, forKey: prefixedAlias)
    }
    
    // Retrieve a key pair and its network by alias
    func get(alias: String) -> (keyPair: KeyPair, network: SolanaSwift.Network)? {
        let prefixedAlias = keyPrefix + alias
        guard let data = keychain.getData(prefixedAlias) else { return nil }
        do {
            let walletData = try JSONDecoder().decode(WalletData.self, from: data)
            return (walletData.keyPair, walletData.network)
        } catch {
            print("Error decoding wallet data: \(error)")
        }
        return nil
    }
    
    // Clear a key pair by alias
    func clear(alias: String) {
        let prefixedAlias = keyPrefix + alias
        keychain.delete(prefixedAlias)
    }
    
    // Get all aliases (without the prefix)
    func getAllAliases() -> [String] {
        return keychain.allKeys
            .filter { $0.hasPrefix(keyPrefix) }
            .map { String($0.dropFirst(keyPrefix.count)) }
    }
    
    // Get all aliases for a specific network
    func getAliases(for network: SolanaSwift.Network) -> [String] {
        return getAllAliases().filter { alias in
            if let walletData = get(alias: alias) {
                return walletData.network == network
            }
            return false
        }
    }
}
