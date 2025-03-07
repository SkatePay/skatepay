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

@MainActor
class FeedDelegate: ObservableObject {
    @Published var messages: [MessageType] = []
    @Published var lead: Lead?
    
    @Published private var dataManager: DataManager?
    @Published private var navigation: Navigation?
    @Published private var network: Network?
    
    private var eventsCancellable: AnyCancellable?
    
    private let keychainForNostr = NostrKeychainStorage()
    
    func setDataManager(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    func setNetwork(network: Network) {
        self.network = network
    }
    
    // MARK: - Subscribe to Channel Events
    
    public func subscribeToChannelWithId(_channelId: String) {
        reset()
        
        guard  let service = network?.eventServiceForChannels else {
            return
        }
        
        service.subscribeToChannelEvents(channelId: _channelId)  { [weak self] in
            self?.handleEvents($0)
        }
    }
    
    // MARK: - Handle Multiple Events in Bulk
    
    private func handleEvents(_ events: [NostrEvent]) {
        var newMessages: [MessageType] = []
        
        let blacklist = self.dataManager?.getBlacklist() ?? []
        
        guard let account = self.keychainForNostr.account else {
            print("❌ Failed to get account")
            return
        }
        
        for event in events {
            if event.kind == .channelCreation {
                if let navigation = self.navigation {
                    navigation.channel = event
                }
                
                self.lead = createLead(from: event)
            } else {
                if let message = MessageHelper.parseEventIntoMessage(event: event, account: account) {
                    guard let publicKey = PublicKey(
                        hex: event.pubkey
                    ) else {
                        continue
                    }
                    
                    if blacklist.contains(
                        publicKey.npub
                    ) {
                        continue
                    }
                    
                    guard let fetchingStoredEvents = self.network?.eventServiceForChannels?.fetchingStoredEvents else {
                        return
                    }
                    
                    if fetchingStoredEvents {
                        newMessages.append(message)
                    } else {
                        newMessages.insert(message, at: 0)
                    }
                }
            }
        }
        
        self.messages.append(
            contentsOf: newMessages
        )
    }
    
    // MARK: - Clean Up Subscriptions
    
    public func reset() {
        messages.removeAll()

        guard  let service = network?.eventServiceForChannels else {
            return
        }
        
        service.cleanUp()
    }
}
