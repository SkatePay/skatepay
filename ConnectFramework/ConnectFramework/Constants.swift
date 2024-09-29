//
//  Constants.swift
//  ConnectFramework
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Foundation

public struct Constants {
    public static let RELAY_URL_DAMUS = "relay.damus.io"
    public static let RELAY_URL_PRIMAL = "wss://relay.primal.net"
    public static let SOLANA_MINT_ADDRESS = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
    public static let SOLANA_TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    public static let SOLANA_TOKEN_LIST_URL =  "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
    public static let NPUB_HUB = "npub1ydcksr7z0a2mk0fnhqkfd0dkgapdgqg2l39mfcuwwwuaeuf6r6qqzq7z7v"
    public static let NCHANNEL_ID = "daa690d701274549da87efbc969bb6b64a5367dbcbef26e116776053696e72ee"
    public static let PICTURE_RABOTA_TOKEN = "https://bafybeierdzfqbppjdv36nnhiiyuwdsccag7la6juvzm4c732q2bmfcvice.ipfs.w3s.link/rabotaToken.png"
    
    public static let API_URL_SKATEPARK = "https://api.skatepark.chat"
    public static let S3_BUCKET = "skateconnect"
}

public struct Keys {
    public static let S3_ACCESS_KEY_ID = ""
    public static let S3_SECRET_ACCESS_KEY = ""
}


public struct ProRobot {
    public static let HELP_URL_SKATEPAY = "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics"
    public static let HELP_URL_SKATECONNECT = "https://support.skatepark.chat"
}

public func hasWallet() -> Bool {
    if let bundleID = Bundle.main.bundleIdentifier {
        if (bundleID == "chat.skatepay.SkatePay") {
            return true
        }
    }
    return false
}
