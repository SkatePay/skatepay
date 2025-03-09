//
//  ChannelMetadataListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import Foundation
import NostrSDK
import os

class ChannelMetadataListener: ObservableObject {
    @Published var metadata: Lead?

    var channelId: String?
    var subscriptionId: String?

    public var cancellables = Set<AnyCancellable>()
    public var receivedEOSE = false

    let log: OSLog

    init() {
        self.log = OSLog(subsystem: "SkateConnect", category: "ChannelMetadata")

        EventBus.shared.didReceiveChannelMetadataSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (channelId, subscriptionId) in
                if (self?.channelId != channelId) { return }
                self?.subscriptionId = subscriptionId
                os_log("🔄 Active metadata subscription: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
            }
            .store(in: &cancellables)

        EventBus.shared.didReceiveEOSE
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                guard case .eose(let subscriptionId) = response else { return }
                if (self?.subscriptionId != subscriptionId) { return }

                os_log("📡 Metadata EOSE received: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
                self?.receivedEOSE = true
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveChannelMetadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.metadata = createLead(from: event.event)
            }
            .store(in: &cancellables)
    }
    
    func setChannelId(_ channelId: String) {
        self.channelId = channelId
    }
    
    func reset() {
        metadata = nil
        receivedEOSE = false
    }
}
