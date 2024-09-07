//
//  Friend.swift
//  Wallet
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
    
    init(name: String, birthday: Date, npub: String) {
        self.name = name
        self.birthday = birthday
        self.npub = npub
    }
    
    var isBirthdayToday: Bool {
        Calendar.current.isDateInToday(birthday) 
    }
}
