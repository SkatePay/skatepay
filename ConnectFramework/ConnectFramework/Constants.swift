//
//  Constants.swift
//  ConnectFramework
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Foundation

public struct Constants {
    public static let RELAY_URL_SKATEPARK = "wss://relay.skatepark.chat"
    
    // https://solana.com/rpc
    public struct SOLANA_DEV {
        public static let ENDPOINT = "https://api.devnet.solana.com"
    }
    
    public struct SOLANA_TEST {
        public static let ENDPOINT = "https://young-soft-water.solana-testnet.quiknode.pro/53648fd7c86c79a516b93973b973745b88261a0c" // "https://api.testnet.solana.com"
    }
    
    public struct SOLANA_MAIN {
        public static let ENDPOINT = "https://mainnet.helius-rpc.com/?api-key=b1016b8c-b125-49e0-8ad0-c2098b03c73e" //"https://api.mainnet-beta.solana.com"
        public static let RABOTA_INFORMATION_URL = "https://prorobot.ai/token/DaEivka37g83C3QMokZmBsUNsAHoh1tm8HhKh8r4Cen5"
    }

    public static let SOLANA_TOKEN_LIST_URL =  "https://raw.githubusercontent.com/SkatePay/token/master/solana.tokenlist.json"
    
    public static let PICTURE_RABOTA_TOKEN = "https://bafybeierdzfqbppjdv36nnhiiyuwdsccag7la6juvzm4c732q2bmfcvice.ipfs.w3s.link/rabotaToken.png"
    
    public static let LANDING_PAGE_HOST = "skatepark.chat"
    public static let LANDING_PAGE_SKATEPARK = "https://skatepark.chat"
    public static let API_URL_SKATEPARK = "https://api.skatepark.chat"
    public static let CHANNEL_URL_SKATEPARK = "https://skatepark.chat/channel"
    public static let S3_BUCKET = "skateconnect"
    
    public struct CHANNELS {
        public static let DECKS = "444c35c272c2480c42f495226edd316b5e9357a2260e72c03a389f75999bbb88"
        public static let FAQ = "f40d36e852fa970310bd14b5422e9e0d72ab326df0ad6b3a4ad4154f452f0356"
    }
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
