//
//  CryptoAddress.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

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

struct CodableCryptoAddress: Codable {
    let address: String
    let blockchain: String
    let network: String

    // Convert CryptoAddress to CodableCryptoAddress
    init(cryptoAddress: CryptoAddress) {
        self.address = cryptoAddress.address
        self.blockchain = cryptoAddress.blockchain
        self.network = cryptoAddress.network
    }
}
