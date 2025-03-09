//
//  Profile.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Foundation


struct Profile {
    var username: String
    var prefersNotifications = true
    var style = Style.regular
    var birthday = Date()
    var gender = Gender.male

    static let `default` = Profile(username: "Skater")

    enum Style: String, CaseIterable, Identifiable {
        case regular = "Regular"
        case goofy = "Goofy"
        case both = "Both"
        
        var id: String { rawValue }
    }
    
    enum Gender: String, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"
        
        var id: String { rawValue }
    }
}
