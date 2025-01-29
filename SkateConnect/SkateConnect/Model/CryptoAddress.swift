//
//  CryptoAddress.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import Foundation

import SwiftData

@Model
class CryptoAddress {
    var address: String
    var blockchain: String
    var network: String
    var friend: Friend?

    init(address: String, blockchain: String, network: String) {
        self.address = address
        self.blockchain = blockchain
        self.network = network
    }
}
