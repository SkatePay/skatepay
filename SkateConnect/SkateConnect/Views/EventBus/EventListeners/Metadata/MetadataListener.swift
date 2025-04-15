//
//  MetadataListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/11/25.
//

import Combine
import Foundation
import MessageKit
import NostrSDK
import os

class MetadataListener: ObservableObject, EventCreating {
    private let log = OSLog(subsystem: "SkateConnect", category: "EventProcessing")

    @Published var metadata: UserMetadata?
    @Published var receivedEOSE = false
    @Published var timestamp = Int64(0)
    
    private var dataManager: DataManager?
    private var debugManager: DebugManager?
    private var account: Keypair?
    
    var publicKey: PublicKey?
    var subscriptionId: String?
    
    public var cancellables = Set<AnyCancellable>()
        
    init() {
        EventBus.shared.didReceiveMetadataSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (publicKey, subscriptionId) in
                
                if (self?.publicKey != publicKey) {
                    return
                }
                
                self?.subscriptionId = subscriptionId
                os_log("🔄 didReceiveMetadataSubscription: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
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
        
        EventBus.shared.didReceiveMetadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.processMetadata(event.event)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        guard let subscriptionId = self.subscriptionId else {
            os_log("🔥 failed to get subscriptionId", log: log, type: .error)
            return
        }
        
        EventBus.shared.didReceiveCloseSubscriptionRequest.send(subscriptionId)
    }
    
    func setPublicKey(_ publicKey: PublicKey) {
        self.publicKey = publicKey
    }
    
    func setDependencies(dataManager: DataManager, debugManager: DebugManager, account: Keypair) {
        self.dataManager = dataManager
        self.debugManager = debugManager
        self.account = account
    }
    
    private func processEventIntoMetadata(_ event: NostrEvent) -> UserMetadata? {
        os_log("⏳ Processing event content: %@", log: log, type: .debug, event.content)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = event.content.data(using: .utf8) else {
            os_log("❌ Failed to convert event content string to Data", log: log, type: .error)
            return nil
        }

        let metadata: UserMetadata
        do {
            metadata = try decoder.decode(UserMetadata.self, from: data)
        } catch {
            os_log("❌ Failed to decode outer Note JSON: %@", log: log, type: .error, String(describing: error))
            return nil
        }
        
        return metadata
    }
    
    private func processMetadata(_ event: NostrEvent) {
        if let metadata = processEventIntoMetadata(event) {
            if (self.receivedEOSE) {
                timestamp = event.createdAt
            } else {
                self.metadata = metadata
            }
        }
    }
    
    func reset() {
        receivedEOSE = false
    }
}
