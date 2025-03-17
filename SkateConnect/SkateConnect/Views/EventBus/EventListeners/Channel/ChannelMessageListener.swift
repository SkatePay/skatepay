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

@MainActor
class ChannelMessageListener: ObservableObject {
    @Published var messages: [MessageType] = []
    @Published var receivedEOSE = false
    @Published var timestamp = Int64(0)

    private var dataManager: DataManager?
    private var debugManager: DebugManager?
    private var account: Keypair?
    
    var channelId: String?
    var subscriptionId: String?
    
    public var cancellables = Set<AnyCancellable>()
    
    let log: OSLog
    
    init() {
        self.log = OSLog(subsystem: "SkateConnect", category: "ChannelMessages")
        
        EventBus.shared.didReceiveChannelMessagesSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (channelId, subscriptionId) in
                if (self?.channelId != channelId) { return }
                self?.subscriptionId = subscriptionId
                os_log("🔄 Active message subscription: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveEOSE
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                guard case .eose(let subscriptionId) = response else { return }
                if (self?.subscriptionId != subscriptionId) { return }
                
                os_log("📡 Messages EOSE received: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
                self?.receivedEOSE = true
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveChannelMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                
                if (event.subscriptionId != self?.subscriptionId) {
                    return
                }
            
                self?.processMessage(event.event)
            }
            .store(in: &cancellables)
    }
    
    func setDependencies(dataManager: DataManager, debugManager: DebugManager, account: Keypair) {
        self.dataManager = dataManager
        self.debugManager = debugManager
        self.account = account
    }
    
    func setChannelId(_ channelId: String) {
        self.channelId = channelId
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
                
        let hasWallet = debugManager?.hasEnabledDebug ?? false
        
        if let message = MessageHelper.parseEventIntoMessage(event: event, account: account, hasWallet: hasWallet) {
            if (self.receivedEOSE) {
                timestamp = event.createdAt

                messages.append(message)
            } else {
                messages.insert(message, at: 0)
            }
        }
    }
    
    func reset() {
        messages.removeAll()
        receivedEOSE = false
    }
}
