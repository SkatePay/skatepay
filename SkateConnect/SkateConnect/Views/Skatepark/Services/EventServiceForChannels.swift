//
//  EventServiceForChannels.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 2/5/25.
//

import ConnectFramework
import Foundation
import NostrSDK
import Combine

class EventServiceForChannels: ObservableObject, EventCreating {
    @Published var fetchingStoredEvents = true
    
    private var events: [NostrEvent] = [] // Buffer for historical messages

    private var network: Network?
    
    public var subscriptionIdForMetadata: String?
    public var subscriptionIdForPublicMessages: String?
    
    private var eventsCancellable: AnyCancellable?
    
    private var callback: (([NostrEvent]) -> Void)?
    
    init(network: Network) {
        self.network = network
    }
    
    // MARK: - Subscriptions
    func subscribeToChannelEvents(channelId: String, completion: @escaping ([NostrEvent]) -> Void) {
        print("🛠 Subscribing to channel: \(channelId)")
        
        cleanUp()  // Reset the service before subscribing to a new channel
        
        self.callback = completion  // Save the completion callback
        
        guard let pool = self.network?.relayPool else {
            print("❌ Relay pool is unavailable")
            return
        }
        
        let filterForMetadata = Filter(
            ids: [channelId],
            kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue]
        )!
        let filterForFeed = Filter(
            kinds: [EventKind.channelMessage.rawValue],
            tags: ["e": [channelId]],
            limit: 32
        )!
        
        self.subscriptionIdForMetadata = pool.subscribe(with: filterForMetadata)
        self.subscriptionIdForPublicMessages = pool.subscribe(with: filterForFeed)
        
        self.eventsCancellable = pool.events
            .receive(on: DispatchQueue.main)
            .map { $0.event }
            .removeDuplicates()
            .sink(receiveValue: self.handleEvent)
        
        print("✅ Subscribed to new channel: \(channelId)")
    }
    
    private func handleEvent(event: NostrEvent) {        
        if self.fetchingStoredEvents {
            self.events.append(event)
        } else {
            guard let callback = self.callback else {
                print("❌ completion is nil! Cannot send event.")
                return
            }
            callback([event])
        }
    }
    
    // MARK: - Flush Buffer Once EOSE is Received
    func flushMessageBuffer() {
        if !events.isEmpty {
            fetchingStoredEvents = false
            callback?(events)
            events.removeAll()
        }
    }
    
    func cleanUp() {
        print("🧹 EventServiceForChannels cleaned up and ready for new subscription")
        
        [subscriptionIdForMetadata, subscriptionIdForPublicMessages]
            .compactMap { $0 }
            .forEach { network?.relayPool?.closeSubscription(with: $0) }
        
        // Reset values
        subscriptionIdForMetadata = nil
        subscriptionIdForPublicMessages = nil
        eventsCancellable?.cancel()
        eventsCancellable = nil
        
        // Clear the buffer and reset states
        events.removeAll()
        callback = nil
        fetchingStoredEvents = true
    }
}
