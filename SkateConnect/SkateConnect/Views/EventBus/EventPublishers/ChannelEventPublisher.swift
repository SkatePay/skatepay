//
//  ChannelEventPublisher.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import os

import Combine
import Foundation
import MessageKit
import NostrSDK

@MainActor
class ChannelEventPublisher: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "ChannelEventPublisher")
    
    public func subscribeToChannelWithId(_ channelId: String) {
        os_log("⏳ requesting subscription to channel [%{public}@]", log: log, type: .info, channelId)

        EventBus.shared.didReceiveChannelSubscriptionRequest.send(channelId)
    }
}
