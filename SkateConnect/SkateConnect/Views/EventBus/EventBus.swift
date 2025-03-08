//
//  EventBus.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import Combine
import NostrSDK

class EventBus: ObservableObject {
    static let shared = EventBus() 

    // DM
    let didReceiveDMSubscriptionRequest = PassthroughSubject<PublicKey, Never>()
    let didReceiveDMSubscription = PassthroughSubject<(publicKey: PublicKey, subscriptionId: String), Never>()

    let didReceiveDMMessage = PassthroughSubject<RelayEvent, Never>()

    // Channel
    let didReceiveChannelSubscriptionRequest = PassthroughSubject<String, Never>()
    let didReceiveChannelSubscription = PassthroughSubject<(channelId: String, subscriptionId: String), Never>()

    let didReceiveChannelMetadata = PassthroughSubject<RelayEvent, Never>()
    let didReceiveChannelMessage = PassthroughSubject<RelayEvent, Never>()

    let didReceiveEOSE = PassthroughSubject<RelayResponse, Never>()
    
}
