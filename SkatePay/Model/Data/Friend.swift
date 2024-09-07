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
     
    init(npub: String, name: String, birthday: Date, note: String) {
        self.npub = npub
        self.name = name
        self.birthday = birthday
        self.note = note
    }
    
    var isBirthdayToday: Bool {
        Calendar.current.isDateInToday(birthday) 
    }
}
