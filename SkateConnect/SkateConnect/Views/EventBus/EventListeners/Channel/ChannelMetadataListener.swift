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
    @Published var lead: Lead?
    
    @Published var channel: Channel?
    
    @Published var receivedEOSE = false

    var type = ChannelType.outbound
    var channelId: String?
    
    var subscriptionId: String?

    var subscriptions = [EventKind: String]()
    var subscriptionIdToEntity = [String: EventKind]() // Reverse lookup

    public var cancellables = Set<AnyCancellable>()

    let log: OSLog

    init() {
        self.log = OSLog(subsystem: "SkateConnect", category: "ChannelMetadata")

        EventBus.shared.didReceiveChannelSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (key, subscriptionId) in
                let channelId = key.channelId
                let kind = key.kind
                
                if (self?.channelId != channelId) { return }
                
                self?.subscriptions[kind] = subscriptionId
                self?.subscriptionIdToEntity[subscriptionId] = kind
                
                os_log("📊 Active subscription — channelId: %{public}@, kind: %{public}@, id: %{public}@",
                       log: self?.log ?? .default, type: .info,
                       channelId, String(describing: kind), subscriptionId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveChannelData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let kind = self?.subscriptionIdToEntity[event.subscriptionId] else { return }

                if kind == .channelCreation {
                    self?.lead = MainHelper.createLead(
                        from: event.event,
                        note: self?.type == .inbound ? "invite" : "",
                        markSpot: self?.type == .inbound
                    )
                    
                    self?.channel = parseChannel(from: event.event)
                }
                
                if kind == .channelMetadata {
                    if let data = parseChannel(from: event.event) {
                        self?.channel?.name = data.name
                        self?.channel?.about = data.about
                        self?.channel?.metadataEvent = event.event
                                                
                        if let channel = self?.channel {
                            self?.lead = MainHelper.updateLead(
                                for: channel,
                                note: self?.type == .inbound ? "invite" : ""
                            )
                        }
                    } else {
                        os_log("❌ Failed to parse channel metadata", log: self?.log ?? .default, type: .error)
                    }
                }
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveEOSE
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                guard case .eose(let subscriptionId) = response else { return }

                guard let kind = self?.subscriptionIdToEntity[subscriptionId] else { return }

                os_log("📡 EOSE received for kind: %{public}@, id: %{public}@",
                       log: self?.log ?? .default, type: .info,
                       String(describing: kind), subscriptionId)

                // Example: only mark EOSE if it's message
                if kind == .channelCreation {
                    self?.receivedEOSE = true
                }
            }
            .store(in: &cancellables)
    }
    
    func setChannelId(_ channelId: String) {
        self.channelId = channelId
    }
    
    func setChannelType(_ type: ChannelType) {
        self.type = type
    }
    
    func reset() {
        lead = nil
        channel = nil
        
        receivedEOSE = false
        
        subscriptionIdToEntity.removeAll()
        subscriptions.removeAll()
    }
}
