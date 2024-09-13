//
//  Foe.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Foundation
import SwiftData

@Model
class Foe {
    @Attribute(.unique) let npub: String
    let birthday: Date
    let note: String
     
    init(npub: String = "", birthday: Date, note: String = "") {
        self.npub = npub
        self.birthday = birthday
        self.note = note
    }
}
