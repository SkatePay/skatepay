//
//  User.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Foundation
import SwiftUI

struct User: Hashable, Codable, Identifiable {
    var id: Int
    var name: String
    var npub: String
    var solanaAddress: String
    var relayUrl: String
    var isFavorite: Bool
    var note: String
    
    private var imageName: String
    var image: Image {
        Image(imageName)
    }
    
    init(id: Int, name: String, npub: String, solanaAddress: String, relayUrl: String, isFavorite: Bool = false, note: String = "", imageName: String = "default") {
        self.id = id
        self.name = name
        self.npub = npub
        self.solanaAddress = solanaAddress
        self.relayUrl = relayUrl
        self.isFavorite = isFavorite
        self.note = note
        self.imageName = imageName
    }
}
