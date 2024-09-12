//
//  SkatePayData.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Foundation

struct AppConstants {
    static let RELAY_URL_DAMUS = "relay.damus.io"
    static let RELAY_URL_PRIMAL = "wss://relay.primal.net"
    static let SOLANA_MINT_ADDRESS = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
    static let SOLANA_TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    static let SOLANA_TOKEN_LIST_URL =  "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
    static let NPUB_HUB = "npub1ydcksr7z0a2mk0fnhqkfd0dkgapdgqg2l39mfcuwwwuaeuf6r6qqzq7z7v"
    static let NCHANNEL_ID = "daa690d701274549da87efbc969bb6b64a5367dbcbef26e116776053696e72ee"
}


@Observable
class AppData {
    var landmarks: [Landmark] = load("landmarkData.json")
    var users: [User] = load("userData.json")
    var profile = Profile.default
}

func load<T: Decodable>(_ filename: String) -> T {
    let data: Data

    guard let file = Bundle.main.url(forResource: filename, withExtension: nil)
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }


    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }


    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}
