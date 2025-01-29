//
//  File.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import ConnectFramework
import Foundation

func getUser(npub: String) -> User {
    var user = User(
        id: 1,
        name: friendlyKey(npub: npub),
        npub: npub,
        solanaAddress: "SolanaAddress1...",
        relayUrl: Constants.RELAY_URL_SKATEPARK,
        isFavorite: false,
        note: "Not provided.",
        imageName: "user-skatepay"
    )
    
    if (npub == AppData().getSupport().npub) {
        user = AppData().users[0]
    }
    
    return user
}
