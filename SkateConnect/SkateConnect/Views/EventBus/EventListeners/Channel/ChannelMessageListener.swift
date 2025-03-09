//
//  ChannelMessageListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import Foundation
import MessageKit
import NostrSDK
import os

class ChannelMessageListener: ChannelSubscriptionListener {
    @Published var messages: [MessageType] = []
    
    private var dataManager: DataManager?
    private var account: Keypair?
    
    override init(category: String = "ChannelMessages") {
        super.init(category: category)

        EventBus.shared.didReceiveChannelMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
                self?.processMessage(event.event)
            }
            .store(in: &cancellables)
    }

    func setDependencies(dataManager: DataManager, account: Keypair) {
        self.dataManager = dataManager
        self.account = account
    }
    
    private func processMessage(_ event: NostrEvent) {
        guard let account = self.account else {
            os_log("🔥 Failed to get account", log: log, type: .error)
            return
        }

        let blacklist = self.dataManager?.getBlacklist() ?? []
        guard let publicKey = PublicKey(hex: event.pubkey), !blacklist.contains(publicKey.npub) else {
            os_log("⛔ Skipping message from blacklisted user", log: log, type: .info)
            return
        }

        if let message = MessageHelper.parseEventIntoMessage(event: event, account: account) {
            if (self.receivedEOSE) {
                messages.append(message)
            } else {
                messages.insert(message, at: 0)
            }
        }
    }
    
    func reset() {
        messages.removeAll()
    }
}
