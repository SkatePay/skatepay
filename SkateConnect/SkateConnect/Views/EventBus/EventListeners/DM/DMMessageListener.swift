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

class DMMessageListener: DMSubscriptionListener, EventCreating {
    @Published var messages: [MessageType] = []
    private var dataManager: DataManager?
    private var account: Keypair?
    
    override init(category: String = "DMMessages") {
        super.init(category: category)

        EventBus.shared.didReceiveDMMessage
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
    
    private func processEventIntoMessage(_ event: NostrEvent) -> MessageType? {
        guard let account = account,
              let publicKey = publicKey else {
            os_log("🔥 Failed to get account or publicKey", log: log, type: .error)
            return nil
        }

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
                                    
            return MessageHelper.parseEventIntoMessage(event: decryptedEvent, account: account)
        } catch {
            print("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func processMessage(_ event: NostrEvent) {
        if let message = processEventIntoMessage(event) {
            if (self.receivedEOSE) {
                messages.append(message)
            } else {
                messages.insert(message, at: 0)
            }
        }
    }
}
