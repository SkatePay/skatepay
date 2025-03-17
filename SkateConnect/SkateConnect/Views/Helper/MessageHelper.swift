//
//  MessageHelper.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/6/25.
//

import ConnectFramework
import CryptoKit
import Foundation
import MessageKit
import NostrSDK
import UIKit


enum Kind: String, Codable {
    case video
    case photo
    case message
    case hidden
    case invoice
    case subscriber
}

struct ContentStructure: Codable {
    let content: String
    let kind: Kind
}

enum ContentType {
    case text(String)
    case attributedText(NSAttributedString)
    case video(URL)
    case photo(URL)
    case invite(String)
    case invoice(String)
}

class MessageHelper {
    static func parseEventIntoMessage(event: NostrEvent, account: Keypair?, hasWallet: Bool = false) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        let displayName = isCurrentUser ? "You" : MainHelper.friendlyKey(npub: npub)
        let user = MockUser(senderId: npub, displayName: displayName)
        
        guard let message = processContent(content: event.content) else {
            print("ignoring hidden message")
            return nil
        }
        
        switch message {
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
        case .invoice(let encryptedString):
            
            if (hasWallet) {
                return processInvoiceMessage(encryptedString, user: user, event: event)
            }
        }
        
        return nil
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
    
    static func processContent(content: String) -> ContentType? {
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
                if let url = URL(string: decodedStructure.content) {
                    return .photo(url)
                } else {
                    print("Invalid photo URL string: \(decodedStructure.content)")
                    return .text(decodedStructure.content) // Fallback to text
                }
                
            case .subscriber:
                let formattedText = "🌴 \(MainHelper.friendlyKey(npub: text)) joined. 🛹"
                return .text(formattedText)
                
                
            case .hidden:
                return nil
                
            default:
                break
            }
            
        } catch let DecodingError.keyNotFound(key, context) {
            print("🔥 Decoding error: Missing key \(key.stringValue) - \(context.debugDescription)")
        } catch {
            print("🔥 Unexpected decoding error: \(error)")
        }
        
        // Handle invoice in the text as a fallback
        if let range = text.range(of: "invoice:") {
            let channelId = String(text[range.upperBound...])
            return .invoice(channelId)
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

// MARK: - Invite
extension MessageHelper {
    static func encryptChannelInviteToString(channel: Channel) -> String? {
        let keyString = "SKATECONNECT"
        let keyData = Data(keyString.utf8)
        let hashedKey = SHA256.hash(data: keyData)
        let symmetricKey = SymmetricKey(data: hashedKey)
        
        do {
            let jsonData = try JSONEncoder().encode(channel)
            let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            print("Error encrypting channel: \(error)")
            return nil
        }
    }
    
    static  func decryptChannelInviteFromString(encryptedString: String) -> Channel? {
        let keyString = "SKATECONNECT"
        let keyData = Data(keyString.utf8)
        let hashedKey = SHA256.hash(data: keyData)
        let symmetricKey = SymmetricKey(data: hashedKey)
        
        do {
            guard let encryptedData = Data(base64Encoded: encryptedString) else {
                print("Error decoding Base64 string")
                return nil
            }
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return try JSONDecoder().decode(Channel.self, from: decryptedData)
        } catch {
            print("Error decrypting channel: \(error)")
            return nil
        }
    }
    
    private static func processInviteMessage(_ encryptedString: String, user: MockUser, event: NostrEvent) -> MessageType? {
        guard let invite = decryptChannelInviteFromString(encryptedString: encryptedString) else {
            print("🔥 Failed to decrypt channel invite")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        guard let inviteEvent = invite.creationEvent else {
            print("🔥 Invite event is nil")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        guard let image = UIImage(named: "user-skatepay") else {
            print("🔥 Failed to load invite thumbnail image")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        guard let lead = MainHelper.createLead(from: inviteEvent), let channel = lead.channel else {
            print("🔥 Failed to create lead from invite event")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        guard let eventId = channel.creationEvent?.id else {
            print("🔥 Failed to get event ID from channel event")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        let urlString = "\(Constants.CHANNEL_URL_SKATEPARK)/\(eventId)?action=invite"
        guard let url = URL(string: urlString) else {
            print("🔥 Failed to generate URL from string: \(urlString)")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        guard let description = channel.aboutDecoded?.description else {
            print("🔥 Failed to decode channel description")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }
        
        var icon = "📺"
        if let note = channel.aboutDecoded?.note {
            icon = note
        }
        
        var inviteString = lead.channelId
        
        if let ecryptedString = encryptChannelInviteToString(channel: channel) {
            inviteString = ecryptedString
        }
        
        let inviteAttributedString = NSAttributedString(
            string: inviteString
        )
        
        let linkItem = MockLinkItem(
            text: "🚪🏃 Channel Invite",
            attributedText: inviteAttributedString,
            url: url,
            title: "\(icon) \(channel.name)",
            teaser: description,
            thumbnailImage: image
        )
        
        return MockMessage(linkItem: linkItem, user: user, messageId: event.id, date: event.createdDate)
    }
}

// MARK: - Invoice
extension MessageHelper {
    static func encryptInvoiceToString(invoice: Invoice) -> String? {
        let keyString = "SKATECONNECT"
        let keyData = Data(keyString.utf8)
        let hashedKey = SHA256.hash(data: keyData)
        let symmetricKey = SymmetricKey(data: hashedKey)
        
        do {
            let jsonData = try JSONEncoder().encode(invoice)
            let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            print("Error encrypting channel: \(error)")
            return nil
        }
    }
    
    static  func decryptInvoiceFromString(encryptedString: String) -> Invoice? {
        let keyString = "SKATECONNECT"
        let keyData = Data(keyString.utf8)
        let hashedKey = SHA256.hash(data: keyData)
        let symmetricKey = SymmetricKey(data: hashedKey)
        
        do {
            guard let encryptedData = Data(base64Encoded: encryptedString) else {
                print("Error decoding Base64 string")
                return nil
            }
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return try JSONDecoder().decode(Invoice.self, from: decryptedData)
        } catch {
            print("Error decrypting invoice: \(error)")
            return nil
        }
    }
    
    private static func processInvoiceMessage(_ encryptedString: String, user: MockUser, event: NostrEvent) -> MessageType? {
        guard let invoice = decryptInvoiceFromString(encryptedString: encryptedString) else {
            print("🔥 Failed to decrypt channel invoice")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        guard let image = UIImage(named: "user-hub") else {
            print("🔥 Failed to load invite thumbnail image")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        let urlString = "\(Constants.CHANNEL_URL_SKATEPARK)/\(event.id)?action=invoice"
        guard let url = URL(string: urlString) else {
            print("🔥 Failed to generate URL from string: \(urlString)")
            return MockMessage(text: encryptedString, user: user, messageId: event.id, date: event.createdDate)
        }

        let parts = invoice.asset.split(separator: ":").map(String.init)
        guard parts.count == 3 else {
            print("🔥 Invalid asset format: expected 3 parts but got \(parts.count) — value: \(invoice.asset)")
            return MockMessage(text: invoice.asset, user: user, messageId: event.id, date: event.createdDate)
        }

        let network = parts[0]
        let symbol = parts[2]

        guard let encoded = Invoice.encodeInvoiceToString(invoice) else {
            print("❌ Failed to encode invoice")
            return MockMessage(text: invoice.asset, user: user, messageId: event.id, date: event.createdDate)
        }

        print("📦 Encoded Invoice: \(encoded)")

        let invoiceAttributedString = NSAttributedString(string: encoded)

        var text = "🫴 Transfer Request"
        
        if (network == "testnet") {
            text = "🫴 Transfer Request (TESTNET)"
        }
        
        let linkItem = MockLinkItem(
            text: text,
            attributedText: invoiceAttributedString,
            url: url,
            title: "\(invoice.amount) \(symbol)",
            teaser: invoice.address,
            thumbnailImage: image
        )

        return MockMessage(linkItem: linkItem, user: user, messageId: event.id, date: event.createdDate)
    }
}
