//
//  Network.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/27/24.
//

import Combine
import ConnectFramework
import CoreLocation
import NostrSDK
import SwiftUI
import SwiftData

class Network: ObservableObject, RelayDelegate, EventCreating {
    @Published var relayPool: RelayPool?
    @Published var connected = false
    
    @Published var shouldScrollToBottom = false
    
    var eventServiceForChannels: EventServiceForChannels?
    var eventServiceForDirect: EventServiceForDirect?
    var leadType = LeadType.outbound

    var lastEventId = ""
    
    private var channelEvents: [String: [NostrEvent]] = [:]
    private var activeSubscriptions: [String] = []
    private var cancellables = Set<AnyCancellable>()

    private let keychainForNostr = NostrKeychainStorage()

    init() {
        self.eventServiceForChannels = EventServiceForChannels(network: self)
        self.eventServiceForDirect = EventServiceForDirect(network: self)
        
        self.observeEvents()
        self.connect()
    }

    func connect() {
        do {
            relayPool = try RelayPool(relayURLs: [URL(string: Constants.RELAY_URL_SKATEPARK)!], delegate: self)
        } catch {
            print("Error initializing RelayPool: \(error)")
        }
    }

    func reconnectRelaysIfNeeded() {
        relayPool?.relays.forEach { relay in
            switch relay.state {
            case .notConnected:
                print("Reconnecting to relay: \(relay.url)")
                self.connect()
            default:
                break
            }
        }
    }

    // MARK: - Relay Delegate
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        switch relay.state {
        case .connected:
            self.connected = true
            Task { await updateSubscriptions() }
        case .notConnected:
            print("Reconnecting to relay: \(relay.url)")
        case .error(let error):
            print("Relay error: \(error.localizedDescription)")
            
            self.connected = false
            
            if error.localizedDescription.contains("Socket is not connected") {
                self.connect()
            }
        default:
            break
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            if (self.lastEventId == event.event.id) {
                self.shouldScrollToBottom = true
            }
        }
    }

    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            
            if let service = self.eventServiceForChannels {
                if subscriptionId == service.subscriptionIdForPublicMessages {
                    service.fetchingStoredEvents = false
                    service.flushMessageBuffer()
                }
            }
            
            if let service = self.eventServiceForDirect {
                if subscriptionId == service.subscriptionIdForPrivateMessages {
                    service.fetchingStoredEvents = false
//                    service.flushMessageBuffer()
                }
            }
        }
    }
    
    // MARK: - Notifications
    private func observeEvents() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.connect() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .uploadVideo)
            .sink { [weak self] notification in
                guard let assetURL = notification.userInfo?["assetURL"] as? String,
                      let channelId = notification.userInfo?["channelId"] as? String else { return }
                self?.publishVideoEvent(channelId: channelId, kind: .video, content: assetURL)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .publishChannelEvent)
            .sink { [weak self] notification in
                guard let content = notification.userInfo?["content"] as? String,
                      let channelId = notification.userInfo?["channelId"] as? String else { return }
                self?.publishChannelEvent(channelId: channelId, content: content)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Event Handlers
extension Network {
    // MARK: - Event Handling
    private func handleIncomingEvent(_ event: NostrEvent) {
        if event.kind == .channelCreation {
            channelEvents[event.id, default: []].append(event)
        }

        switch event.kind {
        case .channelCreation: handleChannelCreation(event)
        case .legacyEncryptedDirectMessage: handleDirectMessage(event)
        case .channelMessage: handleChannelMessage(event)
        default: print("Unhandled event: \(event.kind)")
        }
    }

    private func handleChannelCreation(_ event: NostrEvent) {
        NotificationCenter.default.post(
            name: leadType == .outbound ? .createdChannelForOutbound : .createdChannelForInbound,
            object: event
        )
    }

    private func handleDirectMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedDirectMessage, object: event)
    }

    private func handleChannelMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedChannelMessage, object: event)
    }

}

// MARK: - Subscriptions and Filters
extension Network {
     private var filterForChannels: Filter? {
         guard let account = keychainForNostr.account else {
             print("Error: Failed to create Filter")
             return nil
         }
         let filter = Filter(authors: [account.publicKey.hex], kinds: [EventKind.channelCreation.rawValue])
         return filter
     }
     private var filterForDirectMessages: Filter? {
         guard let account = keychainForNostr.account else {
             print("Error: Failed to create Filter")
             return nil
         }
         let filter = Filter(kinds: [
             EventKind.legacyEncryptedDirectMessage.rawValue,
             EventKind.channelCreation.rawValue
         ], tags: ["p" : [account.publicKey.hex]])
         return filter
     }
    
    // MARK: - Subscriptions
    func updateSubscriptions() async {
        activeSubscriptions.forEach { relayPool?.closeSubscription(with: $0) }
        
        subscribeIfNeeded(filterForChannels)
        subscribeIfNeeded(filterForDirectMessages)

        relayPool?.delegate = self
        relayPool?.events
            .receive(on: DispatchQueue.main)
            .map(\.event)
            .removeDuplicates()
            .sink(receiveValue: handleIncomingEvent)
            .store(in: &cancellables)
    }

    private func subscribeIfNeeded(_ filter: Filter?) {
        guard let filter = filter else { return }
        if let subscription = relayPool?.subscribe(with: filter) {
            activeSubscriptions.append(subscription)
        }
    }
}

// MARK: - Publishers
extension Network {
    func requestOnboardingInfo() async {
        let defaults = UserDefaults.standard
        let key = "hasRequestedOnboardingInfo"
        guard !defaults.bool(forKey: key),
              let account = keychainForNostr.account,
              let recipientPublicKey = PublicKey(npub: AppData().getSupport().npub) else {
            print("Onboarding request already sent or failed.")
            return
        }

        do {
            let message = try legacyEncryptedDirectMessage(withContent: "I'm online.", toRecipient: recipientPublicKey, signedBy: account)
            self.relayPool?.publishEvent(message)
            defaults.set(true, forKey: key)
        } catch {
            print("Failed to send onboarding request: \(error.localizedDescription)")
        }
    }
    
    func publishVideoEvent(channelId: String, kind: Kind = .message, content: String) {
        guard let account = keychainForNostr.account else {
            print("No Nostr account available")
            return
        }

        do {
            let contentStructure = ContentStructure(content: content, kind: kind)
            let encodedContent = String(data: try JSONEncoder().encode(contentStructure), encoding: .utf8) ?? content

            let event = try createChannelMessageEvent(
                withContent: encodedContent,
                eventId: channelId,
                hashtag: "video",
                signedBy: account
            )
            relayPool?.publishEvent(event)
        } catch {
            print("Failed to publish video: \(error.localizedDescription)")
        }
    }

    func publishChannelEvent(channelId: String, kind: Kind = .message, content: String) {
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
                signedBy: account
            )

            self.lastEventId = event.id
            self.relayPool?.publishEvent(event)
        } catch {
            print("Failed to publish message: \(error.localizedDescription)")
        }
    }
   
    func submitDeleteChannelRequestForChannelId(_ channelId: String) {
        guard let account = keychainForNostr.account,
              let relatedEvents = channelEvents[channelId], !relatedEvents.isEmpty else {
            print("Error: No events found for channel deletion.")
            return
        }

        do {
            let deleteRequest = try delete(events: relatedEvents, signedBy: account)
            self.relayPool?.publishEvent(deleteRequest)
        } catch {
            print("Error deleting channel: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let createdChannelForInbound = Notification.Name("createdChannelForInbound")
    static let createdChannelForOutbound = Notification.Name("createdChannelForOutbound")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
}
