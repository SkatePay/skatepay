//
//  DMMessageListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import Foundation
import MessageKit
import NostrSDK
import os

class DMMessageListener: ObservableObject, EventCreating {
    @Published var messages: [MessageType] = []
    @Published var receivedEOSE = false
    @Published var timestamp = Int64(0)
    
    private var dataManager: DataManager?
    private var debugManager: DebugManager?
    private var account: Keypair?
    
    var publicKey: PublicKey?
    var subscriptionId: String?
    
    public var cancellables = Set<AnyCancellable>()

    let log: OSLog
    
    init() {
        self.log = OSLog(subsystem: "SkateConnect", category:  "DMMessages")

        EventBus.shared.didReceiveDMSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (publicKey, subscriptionId) in
                
                if (self?.publicKey != publicKey) {
                    return
                }
                
                self?.subscriptionId = subscriptionId
                os_log("🔄 Active subscription set to: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveEOSE
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                
                guard case .eose(let subscriptionId) = response else {
                    return
                }
                
                if (self?.subscriptionId != subscriptionId) {
                    return
                }
                
                if let log = self?.log {
                    os_log("📡 EOSE received: %{public}@", log: log, type: .info, subscriptionId)
                }
                
                self?.receivedEOSE = true
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveDMMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.processMessage(event.event)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        guard let subscriptionId = self.subscriptionId else {
            os_log("🔥 failed to get subscriptionId", log: log, type: .error)
            return
        }
        EventBus.shared.didReceiveCloseMessagesSubscriptionRequest.send(subscriptionId)
    }
    
    func setPublicKey(_ publicKey: PublicKey) {
        self.publicKey = publicKey
    }
    
    func setDependencies(dataManager: DataManager, debugManager: DebugManager, account: Keypair) {
        self.dataManager = dataManager
        self.debugManager = debugManager
        self.account = account
    }
    
    private func processEventIntoMessage(_ event: NostrEvent) -> MessageType? {
        guard let account = account,
              let publicKey = publicKey else {
            os_log("🔥 Failed to get account or publicKey", log: log, type: .error)
            return nil
        }

        let hasWallet = debugManager?.hasEnabledDebug ?? false
        
        do {
            let decryptedText = try legacyDecrypt(
                encryptedContent: event.content,
                privateKey: account.privateKey,
                publicKey: publicKey
            )
                        
            let decryptedEvent = NostrEvent.Builder(nostrEvent: event)
                .createdAt(event.createdAt)
                .content(decryptedText)
                .build(pubkey: event.pubkey)
                                    
            return MessageHelper.parseEventIntoMessage(event: decryptedEvent, account: account, hasWallet: hasWallet)
        } catch {
            print("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func processMessage(_ event: NostrEvent) {
        if let message = processEventIntoMessage(event) {
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
