//
//  Wallet.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/5/24.
//

import Foundation


class Wallet: ObservableObject {
    static let shared = Wallet()
    
    let keychainForNostr = NostrKeychainStorage()
    
    func isMe(hex: String) -> Bool {
        
        guard let account = keychainForNostr.account else {
            print("Error: Failed to create Filter")
            return false
        }
        
        if (account.publicKey.hex == hex) {
            return true
        }
        
        return false
    }
}
