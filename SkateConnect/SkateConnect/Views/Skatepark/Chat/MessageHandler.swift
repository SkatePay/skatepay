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
    
    let keychainForNostr = NostrKeychainStorage()

    // Add a message to the handler
    func addMessage(_ message: MessageType) {
        messages.append(message)
    }
    
    // Update subscription logic, can be extended
    func updateSubscription() {
        // Logic to handle subscriptions, can be extended or made abstract
    }
    
    // Publish or send a message
    func sendMessage(content: String) {
        // Logic to send a message
    }
    
    func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        
        let content = processContent(content: event.content)
        
        let user = MockUser(senderId: npub, displayName: displayName)
        
        switch content {
        case .text(let text):
            return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
        case .video(let videoURL):
            return MockMessage(thumbnail: videoURL, user: user, messageId: event.id, date: event.createdDate)
        case .photo(let imageUrl):
            return MockMessage(imageURL: imageUrl, user: user, messageId: event.id, date: event.createdDate)
        case .invite(let encryptedString):
            guard let invite = decryptChannelInviteFromString(encryptedString: encryptedString) else {
                print("Failed to decrypt channel invite")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }
            
            guard let image = UIImage(named: "user-skatepay") else {
                print("Failed to load image")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }
            
            guard let event = invite.event, let lead = createLead(from: event) else {
                print("Failed to create lead from event")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }
            
            guard let channel = lead.channel,
                  let url = URL(string: "\(Constants.CHANNEL_URL_SKATEPARK)/\(event.id)"),
                  let description = channel.aboutDecoded?.description else {
                print("Failed to generate URL or decode channel description")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
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
    }
}
