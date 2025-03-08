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

class ChannelMetadataListener: ChannelSubscriptionListener {
    @Published var metadata: Lead?

    override init(category: String = "ChannelMetadata") {
        super.init(category: category)

        EventBus.shared.didReceiveChannelMetadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
                self?.metadata = createLead(from: event.event)
            }
            .store(in: &cancellables)
    }
}
