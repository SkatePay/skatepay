//
//  AwsKeychainStorage.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/28/24.
//

import NostrSDK
import KeychainSwift
import Foundation

public protocol AwsAccountStorage {
    var keys: Keys? { get }
    func save(_ keys: Keys) throws
}

struct AwsKeychainStorage: AwsAccountStorage {
    let tokenKey = "AWS_KEYS"
    let keychain = KeychainSwift()

    func save(_ keys: Keys) throws {
        let data = try JSONEncoder().encode(keys)
        keychain.set(data, forKey: tokenKey)
    }
    
    var keys: Keys? {
        guard let data = keychain.getData(tokenKey) else {return nil}
        
        do {
            let keys = try JSONDecoder().decode(Keys.self, from: data)
            return keys
        } catch {
            print(error)
        }
        return nil
    }
    
    func clear() {
        keychain.delete(tokenKey)
    }
}
