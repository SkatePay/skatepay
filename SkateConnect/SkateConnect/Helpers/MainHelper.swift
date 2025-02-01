//
//  File.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import ConnectFramework
import Foundation
import SwiftUI

func isSupport(npub: String) -> Bool {
    return npub == AppData().getSupport().npub
}

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

func shareVideo(_ videoUrl: URL) {
    // Implementation for sharing the video
    print("Sharing video URL: \(videoUrl)")

    if let url = URL(string: videoUrl.absoluteString) {
        let fileNameWithoutExtension = url.deletingPathExtension().lastPathComponent
        print("File name without extension: \(fileNameWithoutExtension)")
        
        // Construct the custom URL
        let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/video/\(fileNameWithoutExtension)"
        
        // Ensure it's a valid URL
        if let customUrl = URL(string: customUrlString) {
            print("Custom URL: \(customUrl)")
            
            // Open the custom URL
            if UIApplication.shared.canOpenURL(customUrl) {
                UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
            } else {
                print("Unable to open URL: \(customUrl)")
            }
        } else {
            print("Invalid custom URL")
        }
    }
}

func shareChannel(_ channelId: String) {
    // Implementation for sharing channel
    print("Sharing channel with id: \(channelId)")
    
    // Construct the custom URL
    let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/channel/\(channelId)"
    
    // Ensure it's a valid URL
    if let customUrl = URL(string: customUrlString) {
        print("Custom URL: \(customUrl)")
        
        // Open the custom URL
        if UIApplication.shared.canOpenURL(customUrl) {
            UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
        } else {
            print("Unable to open URL: \(customUrl)")
        }
    } else {
        print("Invalid custom URL")
    }
}

func friendlyKey(npub: String) -> String {
    return "Skater-\(npub.suffix(3))"
}
