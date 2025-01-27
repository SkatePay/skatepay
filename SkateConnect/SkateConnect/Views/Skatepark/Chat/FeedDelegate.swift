//
//  FeedDelegate.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/24/25.
//

import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import SwiftUI

class FeedDelegate: ObservableObject {
    @Published var messages: [MessageType] = []
    @Published var lead: Lead?
        
    @Published private var dataManager: DataManager?
    @Published private var navigation: Navigation?
    
    private var eventService = ChannelEventService()
    private var eventsCancellable: AnyCancellable?
    
    private let keychainForNostr = NostrKeychainStorage()
    
    init() {
        eventService = ChannelEventService()
    }
    
    func setDataManager(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    func setNetwork(network: Network) {
        self.eventService.setNetwork(network: network)
    }
    
    // MARK: - Subscribe to Channel Events
    public func subscribeToChannelWithId(_channelId: String, leadType: LeadType = .outbound) {
        
        cleanUp()
        
        // Subscribe to channel events via event service
        eventService.subscribeToChannelEvents(channelId: _channelId, leadType: leadType) { [weak self] events in
            guard let self = self else { return }
            self.handleEvents(events)
        }
    }
    
    // MARK: - Handle Multiple Events in Bulk
    private func handleEvents(_ events: [NostrEvent]) {
        var newMessages: [MessageType] = []
        
        for event in events {
            if let message = parseEventIntoMessage(event: event) {
                if event.kind == .channelCreation {
                    if let navigation = navigation {
                        navigation.channel = event
                    }
                    
                    DispatchQueue.main.async {
                        self.lead = createLead(from: event)
                    }
                }
                
                // Only add channel messages to newMessages array
                if event.kind == .channelMessage {
                    guard let publicKey = PublicKey(hex: event.pubkey) else { continue }
                    if getBlacklist().contains(publicKey.npub) { continue }
                    
                    // Append messages depending on whether we are fetching stored events or live events
                    if eventService.fetchingStoredEvents {
                        newMessages.insert(message, at: 0)  // Prepend historical messages
                    } else {
                        newMessages.append(message)  // Append live messages
                    }
                }
            }
        }
        
        // Batch update the messages array with new messages
        DispatchQueue.main.async {
            self.messages.append(contentsOf: newMessages)
        }
    }
    
    // MARK: - Publish Draft Message
    public func publishDraft(text: String, kind: Kind = .message) {
        // Ensure channelId is not nil
        guard let channelId = navigation?.channelId else {
            print("Error: Channel ID is nil.")
            return
        }
        
        // Delegate to ChannelEventService for publishing the message
        eventService.publishMessage(text, channelId: channelId, kind: kind)
    }
    
    // MARK: - Clean Up Subscriptions
    public func cleanUp() {
        // Remove all stored messages and cancel any existing subscriptions
        messages.removeAll()
        eventService.cleanUp()
    }
    
    // MARK: - Parse Nostr Event into MessageType
    private func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        
        let content = processContent(content: event.content)
        let user = MockUser(senderId: npub, displayName: displayName)
        
        switch content {
        case .text(let text):
            // Handle text message
            return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
        case .video(let videoURL):
            // Handle video message
            return MockMessage(thumbnail: videoURL, user: user, messageId: event.id, date: event.createdDate)
        case .photo(let imageUrl):
            // Handle photo message
            return MockMessage(imageURL: imageUrl, user: user, messageId: event.id, date: event.createdDate)
        case .invite(let encryptedString):
            // Handle invite message
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
    
    // MARK: - Blacklist Handling
    func getBlacklist() -> [String] {
        // Get list of blacklisted users (foes)
        guard let dataManager = dataManager else {
            return []
        }
        return dataManager.fetchFoes().map { $0.npub }
    }
}
