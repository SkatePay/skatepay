//
//  Constants.swift
//  ConnectFramework
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Foundation

public struct Constants {
    public static let RELAY_URL_SKATEPARK = "wss://relay.skatepark.chat"
    
    public struct SOLANA_DEV {
        public static let MINT_ADDRESS = ""
        public static let TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
        public static let ENDPOINT = "https://api.devnet.solana.com"
    }
    
    public struct SOLANA_TEST {
        public static let MINT_ADDRESS = "rabpv2nxTLxdVv2SqzoevxXmSD2zaAmZGE79htseeeq"
        public static let TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
        public static let ENDPOINT = "https://young-soft-water.solana-testnet.quiknode.pro/53648fd7c86c79a516b93973b973745b88261a0c" // "https://api.testnet.solana.com"
    }
    
    // https://solana.com/rpc
    public struct SOLANA_MAIN {
        public static let MINT_ADDRESS = ""
        public static let TOKEN_PROGRAM_ID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
        public static let ENDPOINT = "https://mainnet.helius-rpc.com/?api-key=b1016b8c-b125-49e0-8ad0-c2098b03c73e" //"https://api.mainnet-beta.solana.com"
    }

    public static let SOLANA_TOKEN_LIST_URL =  "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
    
    public static let PICTURE_RABOTA_TOKEN = "https://bafybeierdzfqbppjdv36nnhiiyuwdsccag7la6juvzm4c732q2bmfcvice.ipfs.w3s.link/rabotaToken.png"
    
    public static let LANDING_PAGE_HOST = "skatepark.chat"
    public static let LANDING_PAGE_SKATEPARK = "https://skatepark.chat"
    public static let API_URL_SKATEPARK = "https://api.skatepark.chat"
    public static let CHANNEL_URL_SKATEPARK = "https://skatepark.chat/channel"
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
