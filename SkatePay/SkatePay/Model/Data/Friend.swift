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
    let solanaAddress: String
    let note: String
     
    init(name: String, birthday: Date, npub: String = "", solanaAddress: String = "", note: String = "") {
        self.name = name
        self.birthday = birthday
        self.npub = npub
        self.solanaAddress = solanaAddress
        self.note = note
    }
    
    var isBirthdayToday: Bool {
        Calendar.current.isDateInToday(birthday) 
    }
}
