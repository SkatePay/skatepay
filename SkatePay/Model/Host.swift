//
//  Host.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import Foundation
import NostrSDK

struct Host: Hashable, Codable {
    var privateKey: String = ""
    var publicKey: String = ""
    var nsec: String = ""
    var npub: String = ""
    
    var relayUrls: [String] = [AppConstants.RELAY_URL_PRIMAL]
    
    private var noValueString = ""
    
    init() {
        self.publicKey = noValueString
        self.privateKey = noValueString
        self.npub = noValueString
        self.nsec = noValueString
    }
    
    init(publicKey: String = "", privateKey: String = "", npub: String = "", nsec: String = "") {
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.npub = npub
        self.nsec = nsec
    }
}

