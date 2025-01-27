//
//  ChannelEventService.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import ConnectFramework
import Foundation
import NostrSDK
import Combine

class ChannelEventService: ObservableObject, RelayDelegate, EventCreating {
    @Published private var network: Network?

    private let keychainForNostr = NostrKeychainStorage()

    private var relayPool: RelayPool? {
        return network?.getRelayPool()
    }

    private var subscriptionIdForMetadata: String?
    private var subscriptionIdForPublicMessages: String?

    private var eventsCancellable: AnyCancellable?
    
    var fetchingStoredEvents: Bool = true // Flag to track stored events
    private var messageBuffer: [NostrEvent] = [] // Buffer for historical messages
    private var bufferCompletion: (([NostrEvent]) -> Void)?

    func setNetwork(network: Network) {
        self.network = network
    }
    
    // MARK: - Subscribe to Event Streams
    func subscribeToChannelEvents(channelId: String, leadType: LeadType = .outbound, completion: @escaping ([NostrEvent]) -> Void){
        
        self.network?.leadType = leadType
        self.bufferCompletion = completion  // Save the completion for later use
        
        let filterForMetadata = Filter(ids: [channelId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
        let filterForFeed = Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [channelId]], limit: 32)!
        
        subscriptionIdForMetadata = relayPool?.subscribe(with: filterForMetadata)
        subscriptionIdForPublicMessages = relayPool?.subscribe(with: filterForFeed)
        
        eventsCancellable = relayPool?.events
            .receive(on: DispatchQueue.main)
            .map { $0.event }
            .removeDuplicates()
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
    }

    // MARK: - Handle Relay Responses (e.g., End of Stored Events)
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            // If it's the public message subscription, stop fetching stored events
            if subscriptionId == self.subscriptionIdForPublicMessages {
                self.fetchingStoredEvents = false
                self.flushMessageBuffer()
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
    private func flushMessageBuffer() {
        if !messageBuffer.isEmpty {
            // Pass all buffered messages at once
            bufferCompletion?(messageBuffer)
            messageBuffer.removeAll() // Clear the buffer
        }
    }

    // MARK: - Publish Messages
    func publishMessage(_ content: String, channelId: String, kind: Kind) {
        guard let account = keychainForNostr.account else {
            print("No Nostr account available for publishing")
            return
        }

        do {
            let contentStructure = ContentStructure(content: content, kind: kind)
            let encoder = JSONEncoder()
            let data = try encoder.encode(contentStructure)
            let contentString = String(data: data, encoding: .utf8) ?? content

            let event = try createChannelMessageEvent(
                withContent: contentString,
                eventId: channelId,
                relayUrl: Constants.RELAY_URL_SKATEPARK,
                signedBy: account
            )

            relayPool?.publishEvent(event)
        } catch {
            print("Failed to publish message: \(error.localizedDescription)")
        }
    }

    func cleanUp() {
        [subscriptionIdForMetadata, subscriptionIdForPublicMessages].compactMap { $0 }.forEach {
            relayPool?.closeSubscription(with: $0)
        }
        
        subscriptionIdForMetadata = nil
        subscriptionIdForPublicMessages = nil
        
        fetchingStoredEvents = true
        
        relayPool?.delegate = self
        
        eventsCancellable?.cancel()
    }

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        // Handle relay state changes
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        // Handle received event from relay
    }
}
