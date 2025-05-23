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
    // Metadata
    let didReceiveMetadataSubscriptionRequest = PassthroughSubject<PublicKey, Never>()
    
    let didReceiveMetadataSubscription = PassthroughSubject<(publicKey: PublicKey, subscriptionId: String), Never>()
    let didReceiveMetadata = PassthroughSubject<RelayEvent, Never>()
    
    // Notes
    let didReceiveNotesSubscriptionRequest = PassthroughSubject<PublicKey, Never>()

    let didReceiveNotesSubscription = PassthroughSubject<(publicKey: PublicKey, subscriptionId: String), Never>()
    let didReceiveNote = PassthroughSubject<RelayEvent, Never>()

    // DM
    let didReceiveDMSubscriptionRequest = PassthroughSubject<PublicKey, Never>()
    let didReceiveDMSubscription = PassthroughSubject<(publicKey: PublicKey, subscriptionId: String), Never>()
    
    let didReceiveDMMessage = PassthroughSubject<RelayEvent, Never>()
    
    // Channel
    typealias ChannelSubscriptionRequest = (kind: EventKind, channelId: String)

    let didReceiveChannelSubscriptionRequest = PassthroughSubject<ChannelSubscriptionRequest, Never>()
    
    let didReceiveChannelSubscription = PassthroughSubject<(key: ChannelSubscriptionKey, subscriptionId: String), Never>()
    
    let didReceiveChannelData = PassthroughSubject<RelayEvent, Never>()
    
    let didReceiveChannelMessagesSubscription = PassthroughSubject<(channelId: String, subscriptionId: String), Never>()

    let didReceiveChannelMessage = PassthroughSubject<RelayEvent, Never>()
    
    typealias ChannelMetadataRequest = (channelId: String, metadata: ChannelMetadata)
    
    let didReceiveChannelMetadata = PassthroughSubject<ChannelMetadataRequest, Never>()
    
    let didReceiveEOSE = PassthroughSubject<RelayResponse, Never>()
    
    let didReceiveCloseMetadataSubscriptionRequest = PassthroughSubject<(String, EventKind), Never>()
    let didReceiveCloseMessagesSubscriptionRequest = PassthroughSubject<String, Never>()

    let didReceiveCloseSubscriptionRequest = PassthroughSubject<String, Never>()
}
