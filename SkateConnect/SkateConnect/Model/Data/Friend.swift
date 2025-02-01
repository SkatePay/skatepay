//
//  Friend.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/3/24.
//

import Foundation
import SwiftData

@Model
class Friend {
    @Attribute(.unique) let name: String
    let birthday: Date
    let npub: String
    let note: String
    @Relationship(deleteRule: .cascade) var cryptoAddresses: [CryptoAddress] = []
     
    init(name: String, birthday: Date, npub: String = "", note: String = "") {
        self.name = name
        self.birthday = birthday
        self.npub = npub
        self.note = note
        
    }
    
    var isBirthdayToday: Bool {
        Calendar.current.isDateInToday(birthday) 
    }
}

struct CodableFriend: Codable {
    let name: String
    let birthday: String  // Convert `Date` to String
    let npub: String
    let note: String
    let cryptoAddresses: [CodableCryptoAddress]

    // Convert Date to String for JSON storage
    init(friend: Friend) {
        self.name = friend.name
        self.birthday = ISO8601DateFormatter().string(from: friend.birthday)
        self.npub = friend.npub
        self.note = friend.note
        self.cryptoAddresses = friend.cryptoAddresses.map { address in
            CodableCryptoAddress(cryptoAddress: address)
        }
    }
}
