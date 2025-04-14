//
//  File.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import os
import ConnectFramework
import Foundation
import NostrSDK
import SwiftUI

class MainHelper {

    static func isSupport(npub: String) -> Bool {
        return npub == AppData().getSupport().npub
    }
    
    static func getUser(npub: String, name: String?) -> User {
        var user = User(
            id: 1,
            name: name ?? friendlyKey(npub: npub),
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
    
    static func shareVideo(_ videoUrl: URL) {
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
    
    static func shareChannel(_ channelId: String) {
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
    
    static func friendlyKey(npub: String) -> String {
        return "Skater-\(npub.suffix(3))"
    }
    
    static func convertNoteToColor(_ note: String) -> Color {
        let color: Color
        switch note {
        case "invite":
            color = Color(uiColor: UIColor.systemIndigo)
        case "public":
            color = Color(uiColor: UIColor.systemGray)
        case "private":
            color = .purple
        default:
            color = Color(uiColor: UIColor.systemBlue)
        }
        return color;
    }
    
    static func createLead(from event: NostrEvent, note: String = "", markSpot: Bool = false) -> Lead? {
        var lead: Lead?
        
        if let channel = parseChannel(from: event) {
            let about = channel.about
            
            do {
                let decoder = JSONDecoder()
                let decodedStructure = try decoder.decode(AboutStructure.self, from: about.data(using: .utf8)!)
                
                let icon = decodedStructure.note ?? "📡"
                let coordinate = decodedStructure.location
                let color = convertNoteToColor(note)
                
                lead = Lead(
                    name: channel.name,
                    icon: icon,
                    note: note,
                    coordinate: coordinate,
                    channelId: event.id,
                    channel: channel,
                    color: color
                )
                
                if (markSpot) {
                    NotificationCenter.default.post(name: .markSpot, object: lead)
                }
            } catch {
                print("Error decoding: \(error)")
            }
        }
        return lead
    }
    
    static func updateLead(for channel: Channel, note: String = "") {
        guard
            let creationEvent = channel.creationEvent,
            let aboutData = channel.metadata?.about?.data(using: .utf8) ?? channel.about.data(using: .utf8)
        else {
            print("⚠️ Missing events or invalid about data")
            return
        }

        do {
            let decodedStructure = try JSONDecoder().decode(AboutStructure.self, from: aboutData)

            let icon = decodedStructure.note ?? "📡"
            let coordinate = decodedStructure.location
            let color = convertNoteToColor(note)

            let lead = Lead(
                name: channel.metadata?.name ?? channel.name,
                icon: icon,
                note: note,
                coordinate: coordinate,
                channelId: creationEvent.id,
                channel: channel,
                color: color
            )

            NotificationCenter.default.post(name: .updateSpot, object: lead)

            return
        } catch {
            print("Error decoding AboutStructure: \(error)")
            return
        }
    }
}
