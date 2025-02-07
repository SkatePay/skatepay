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

    private var network: Network?

    public var subscriptionIdForMetadata: String?
    public var subscriptionIdForPublicMessages: String?

    private var eventsCancellable: AnyCancellable?
    
    private var messageBuffer: [NostrEvent] = [] // Buffer for historical messages
    private var bufferCompletion: (([NostrEvent]) -> Void)?

    init(network: Network) {
        self.network = network
    }
    
    // MARK: - Subscriptions
    func subscribeToChannelEvents(channelId: String, completion: @escaping ([NostrEvent]) -> Void){
        
        self.bufferCompletion = completion  // Save the completion for later use
        
        if let pool = network?.relayPool {
            let filterForMetadata = Filter(ids: [channelId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
            let filterForFeed = Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [channelId]], limit: 32)!
            
            subscriptionIdForMetadata = pool.subscribe(with: filterForMetadata)
            subscriptionIdForPublicMessages = pool.subscribe(with: filterForFeed)
            
            eventsCancellable = pool.events
                .receive(on: DispatchQueue.main)
                .map { $0.event }
                .removeDuplicates()
                .sink { [weak self] event in
                    self?.handleEvent(event)
                }
        }
    }
    
    // MARK: - Buffer Historical Messages
    private func handleEvent(_ event: NostrEvent) {
        if fetchingStoredEvents {
//            messageBuffer.append(event)
            messageBuffer.insert(event, at: 0)
        } else {
            // For live events, send directly to UI
            bufferCompletion?([event])
        }
    }

    // MARK: - Flush Buffer Once EOSE is Received
    func flushMessageBuffer() {
        if !messageBuffer.isEmpty {
            // Pass all buffered messages at once
            bufferCompletion?(messageBuffer)
            messageBuffer.removeAll() // Clear the buffer
        }
    }
    

    func cleanUp() {
        [subscriptionIdForMetadata, subscriptionIdForPublicMessages].compactMap { $0 }.forEach {
            network?.relayPool?.closeSubscription(with: $0)
        }
        
        subscriptionIdForMetadata = nil
        subscriptionIdForPublicMessages = nil
        
        fetchingStoredEvents = true
                
        eventsCancellable?.cancel()
    }
}
