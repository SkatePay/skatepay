//
//  DMSubscriptionListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import Foundation
import NostrSDK
import os

@MainActor
class DMSubscriptionListener: ObservableObject {
    @Published var events: [RelayEvent] = []

    var publicKey: PublicKey?
    var subscriptionId: String?
    
    public var cancellables = Set<AnyCancellable>()
    public var receivedEOSE = false

    let log: OSLog
    
    init(category: String) {
        self.log = OSLog(subsystem: "SkateConnect", category: category)

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
    }
    
    func setPublicKey(_ publicKey: PublicKey) {
        self.publicKey = publicKey
    }
    
    func handleEvent(_ event: RelayEvent) {
        guard event.subscriptionId == subscriptionId else {
            os_log("⏭️ Ignoring event from different subscription: %{public}@", log: log, type: .info, event.subscriptionId)
            return
        }
        
//        os_log("📡 Event received: %{public}@", log: log, type: .info, event.event.id)
        events.append(event)
    }
}
