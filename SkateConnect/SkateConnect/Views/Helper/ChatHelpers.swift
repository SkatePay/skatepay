//
//  ChatHelpers.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/18/24.
//

import SwiftUI

enum ContentType {
    case text(String)
    case video(URL)
    case photo(URL)
    case invite(String)
}

func processContent(content: String) -> ContentType {
    var text = content
    
    do {
        let decodedStructure = try JSONDecoder().decode(ContentStructure.self, from: content.data(using: .utf8)!)
        text = decodedStructure.content
        
        switch decodedStructure.kind {
        case .video:
            // Convert .mov to .jpg for the thumbnail
            let urlString = decodedStructure.content.replacingOccurrences(of: ".mov", with: ".jpg")
            if let url = URL(string: urlString) {
                return .video(url)
            } else {
                print("Invalid video thumbnail URL string: \(urlString)")
                return .text(decodedStructure.content) // Fallback to text
            }
            
        case .photo:
            // Handle photo content
            if let url = URL(string: decodedStructure.content) {
                return .photo(url)
            } else {
                print("Invalid photo URL string: \(decodedStructure.content)")
                return .text(decodedStructure.content) // Fallback to text
            }
            
        case .subscriber:
            // Format the subscriber text
            let formattedText = "🌴 \(friendlyKey(npub: text)) joined. 🛹"
            return .text(formattedText)
            
        default:
            // If no other kind is matched, fall through to check for channel_invite or return raw text
            break
        }
        
    } catch {
        print("Decoding error: \(error)")
    }
    
    // Handle channel_invite in the text as a fallback
    if let range = text.range(of: "channel_invite:") {
        let channelId = String(text[range.upperBound...])
        return .invite(channelId)
    }
    
    // Return the original text if no special cases are matched
    return .text(text)
}
