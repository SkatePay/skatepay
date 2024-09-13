//
//  SolanaKeychainStorage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import SolanaSwift
import KeychainSwift
import Foundation

struct SolanaKeychainStorage: SolanaAccountStorage {
    let tokenKey = "SOLANA_KEYPAIR"
    let keychain = KeychainSwift()

    func save(_ account: KeyPair) throws {
        let data = try JSONEncoder().encode(account)
        keychain.set(data, forKey: tokenKey)
    }
    
    var account: KeyPair? {
        guard let data = keychain.getData(tokenKey) else {return nil}
        
        do {
            let keyPair = try JSONDecoder().decode(KeyPair.self, from: data)
            return keyPair
        } catch {
            print(error)
        }
        return nil
    }
    
    func clear() {
        keychain.delete(tokenKey)
    }
}
