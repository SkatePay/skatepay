//
//  EventBus.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import NostrSDK

enum ChannelSubscriptionRequestType: String {
    case metadata = "metadata"
    case messages = "messages"
}

class EventBus: ObservableObject {
    static let shared = EventBus()
    
    // DM
    let didReceiveDMSubscriptionRequest = PassthroughSubject<PublicKey, Never>()
    let didReceiveDMSubscription = PassthroughSubject<(publicKey: PublicKey, subscriptionId: String), Never>()
    
    let didReceiveDMMessage = PassthroughSubject<RelayEvent, Never>()
    
    // Channel
    typealias ChannelSubscriptionRequest = (type: ChannelSubscriptionRequestType, channelId: String)

    let didReceiveChannelSubscriptionRequest = PassthroughSubject<ChannelSubscriptionRequest, Never>()
    
    let didReceiveChannelMetadataSubscription = PassthroughSubject<(channelId: String, subscriptionId: String), Never>()
    let didReceiveChannelMessagesSubscription = PassthroughSubject<(channelId: String, subscriptionId: String), Never>()

    let didReceiveChannelMetadata = PassthroughSubject<RelayEvent, Never>()
    let didReceiveChannelMessage = PassthroughSubject<RelayEvent, Never>()
    
    let didReceiveEOSE = PassthroughSubject<RelayResponse, Never>()
}
