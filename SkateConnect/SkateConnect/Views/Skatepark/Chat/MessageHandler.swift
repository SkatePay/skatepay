//
//  MessageHandler.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/7/24.
//

import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import UIKit

class MessageHandler: ObservableObject {
    @Published var messages: [MessageType] = []
    
    private let keychainForNostr = NostrKeychainStorage()

    // Add a new message to the list
    func addMessage(_ message: MessageType) {
        messages.append(message)
    }
    
    // Update subscription logic (to be extended as needed)
    func updateSubscription() {
        // Placeholder for future subscription logic
    }
    
    // Publish or send a message
    func sendMessage(content: String) {
        // Placeholder for sending message logic
    }
    
    // Convert a Nostr event into a MessageType instance
    func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        guard let publicKey = PublicKey(hex: event.pubkey) else { return nil }
        
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        let npub = publicKey.npub ?? ""
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        let content = processContent(content: event.content)
        let user = MockUser(senderId: npub, displayName: displayName)

        switch content {
        case .text(let text):
            return MockMessage(
                text: text,
                user: user,
                messageId: event.id,
                date: event.createdDate
            )
            
        case .video(let videoURL):
            return MockMessage(
                thumbnail: videoURL,
                user: user,
                messageId: event.id,
                date: event.createdDate
            )
            
        case .photo(let imageUrl):
            return MockMessage(
                imageURL: imageUrl,
                user: user,
                messageId: event.id,
                date: event.createdDate
            )
            
        case .invite(let encryptedString):
            return parseInviteMessage(encryptedString: encryptedString, user: user, event: event)
        }
    }

    // Helper function to parse invite messages
    private func parseInviteMessage(encryptedString: String, user: MockUser, event: NostrEvent) -> MessageType? {
        guard let invite = decryptChannelInviteFromString(encryptedString: encryptedString) else {
            print("Failed to decrypt channel invite")
            return createFallbackMessage(encryptedString, user: user)
        }
        
        guard let image = UIImage(named: "user-skatepay") else {
            print("Failed to load image")
            return createFallbackMessage(encryptedString, user: user)
        }
        
        guard let event = invite.event, let lead = createLead(from: event, note: "invite") else {
            print("Failed to create lead from event")
            return createFallbackMessage(encryptedString, user: user)
        }
        
        guard let channel = lead.channel,
              let url = URL(string: "\(Constants.CHANNEL_URL_SKATEPARK)/\(event.id)"),
              let description = channel.aboutDecoded?.description else {
            print("Failed to generate URL or decode channel description")
            return createFallbackMessage(encryptedString, user: user)
        }

        let linkItem = MockLinkItem(
            text: "\(lead.icon) Channel Invite",
            attributedText: nil,
            url: url,
            title: "🪧 \(lead.name)",
            teaser: description,
            thumbnailImage: image
        )

        return MockMessage(
            linkItem: linkItem,
            user: user,
            messageId: event.id,
            date: event.createdDate
        )
    }
    
    // Fallback message for failed invite parsing
    private func createFallbackMessage(_ text: String, user: MockUser) -> MessageType {
        return MockMessage(
            text: text,
            user: user,
            messageId: "unknown",
            date: Date()
        )
    }
}
