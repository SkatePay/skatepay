//
//  NostrKeychainStorage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import SolanaSwift
import NostrSDK
import KeychainSwift
import Foundation

struct NostrKeypair: Encodable, Decodable {
    let privateKey: String
    let publicKey: String
}
public protocol NostrAccountStorage {
    var account: Keypair? { get }
    func save(_ account: Keypair) throws
}

struct NostrKeychainStorage: NostrAccountStorage {
    let tokenKey = "NOSTR_KEYPAIR"
    let keychain = KeychainSwift()

    func save(_ account: Keypair) throws {
        let keypair = NostrKeypair(privateKey: account.privateKey.hex, publicKey: account.publicKey.hex)
        let data = try JSONEncoder().encode(keypair)
        keychain.set(data, forKey: tokenKey)
    }
    
    var account: Keypair? {
        guard let data = keychain.getData(tokenKey) else {return nil}
        
        do {
            let keypair = try JSONDecoder().decode(NostrKeypair.self, from: data)
            
            guard let account = Keypair(hex: keypair.privateKey) else {return nil}
            return account
        } catch {
            print(error)
        }
        return nil
    }
    
    func clear() {
        keychain.delete(tokenKey)
    }
}

