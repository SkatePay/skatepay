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
