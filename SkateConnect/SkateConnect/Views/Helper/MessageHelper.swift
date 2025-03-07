//
//  MessageHelper.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/6/25.
//

import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import UIKit

enum ContentType {
    case text(String)
    case attributedText(NSAttributedString)
    case video(URL)
    case photo(URL)
    case invite(String)
}

class MessageHelper {
    /// Parses a `NostrEvent` into a `MessageType`
    static func parseEventIntoMessage(event: NostrEvent, account: Keypair?) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        
        let content = processContent(content: event.content)
        let user = MockUser(senderId: npub, displayName: displayName)

        switch content {
        case .attributedText(let text):
            return MockMessage(attributedText: text, user: user, messageId: event.id, date: event.createdDate)
        case .text(let text):
            return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
        case .video(let videoURL):
            return MockMessage(thumbnail: videoURL, user: user, messageId: event.id, date: event.createdDate)
        case .photo(let imageUrl):
            return MockMessage(imageURL: imageUrl, user: user, messageId: event.id, date: event.createdDate)
        case .invite(let encryptedString):
            return processInviteMessage(encryptedString, user: user, event: event)
        }
    }
    
    /// Handles the parsing of an encrypted invite message
    private static func processInviteMessage(_ encryptedString: String, user: MockUser, event: NostrEvent) -> MessageType? {
        guard let invite = decryptChannelInviteFromString(encryptedString: encryptedString) else {
            print("❌ Failed to decrypt channel invite")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let inviteEvent = invite.event else {
            print("❌ Invite event is nil")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let image = UIImage(named: "user-skatepay") else {
            print("❌ Failed to load invite thumbnail image")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let lead = createLead(from: inviteEvent), let channel = lead.channel else {
            print("❌ Failed to create lead from invite event")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let eventId = channel.event?.id else {
            print("❌ Failed to get event ID from channel event")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        let urlString = "\(Constants.CHANNEL_URL_SKATEPARK)/\(eventId)"
        guard let url = URL(string: urlString) else {
            print("❌ Failed to generate URL from string: \(urlString)")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let description = channel.aboutDecoded?.description else {
            print("❌ Failed to decode channel description")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        let linkItem = MockLinkItem(
            text: "\(lead.icon) Channel Invite",
            attributedText: nil,
            url: url,
            title: "🪧 \(lead.name)",
            teaser: description,
            thumbnailImage: image
        )

        return MockMessage(linkItem: linkItem, user: user, messageId: event.id, date: event.createdDate)
    }
    
    
    static func detectAndConvertLinks(_ text: String) -> NSAttributedString? {
        // Match MessageKit's default appearance (white color, default font size)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: attributes
        )
            
        // Improved regex for detecting URLs
        let linkPattern = #"(https?:\/\/[^\s]+|www\.[^\s]+)"#
        
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: []) else {
            return nil
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        var foundLinks = false

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            
            let urlString = (text as NSString).substring(with: match.range)
            let finalURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"

            if let url = URL(string: finalURL) {
                // Explicitly set attributes for links to keep text white and underline blue
                attributedString.addAttributes([
                    .link: url,
                ], range: match.range)
                
                foundLinks = true
            }
        }

        return foundLinks ? attributedString : nil
    }

    static func processContent(content: String) -> ContentType {
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
            
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ Decoding error: Missing key \(key.stringValue) - \(context.debugDescription)")
        } catch {
            print("❌ Unexpected decoding error: \(error)")
        }
        
        // Handle channel_invite in the text as a fallback
        if let range = text.range(of: "channel_invite:") {
            let channelId = String(text[range.upperBound...])
            return .invite(channelId)
        }
        
        // Detect URLs in plain text
        if let attributedText = MessageHelper.detectAndConvertLinks(text) {
            return .attributedText(attributedText)
        }
        
        // Return the original text if no special cases are matched
        return .text(text)
    }
}
