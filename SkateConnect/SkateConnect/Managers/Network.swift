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
    @Published var fetchingStoredEvents = true
    @Published var connected = false
    
    private var channelEvents: [String: [NostrEvent]] = [:]
    private var activeSubscriptions: [String] = []
    private var cancellables = Set<AnyCancellable>()

    private let keychainForNostr = NostrKeychainStorage()
    var leadType = LeadType.outbound

    init() {
        connect()
        observeAppLifecycle()
        startListening()
    }

    // MARK: - Relay Management
    func connect() {
        do {
            relayPool = try RelayPool(relayURLs: [URL(string: Constants.RELAY_URL_SKATEPARK)!], delegate: self)
        } catch {
            print("Error initializing RelayPool: \(error)")
        }
    }

    func getRelayPool() -> RelayPool {
        reconnectRelaysIfNeeded()
        return relayPool!
    }

    func reconnectRelaysIfNeeded() {
        relayPool?.relays.forEach { relay in
            switch relay.state {
            case .notConnected:
                print("Reconnecting to relay: \(relay.url)")
            case .error(let error):
                print("Relay error: \(error.localizedDescription)")
                if error.localizedDescription.contains("Socket is not connected") || error.localizedDescription.contains("offline") {
                    connect()
                }
            default:
                break
            }
        }
    }

    // MARK: - Relay Delegate
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if state == .connected {
            connected = true
            Task { await updateSubscriptions() }
        } else {
            connected = false
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {}

    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        if case .eose = response {
            DispatchQueue.main.async { self.fetchingStoredEvents = false }
        }
    }

    // MARK: - Subscriptions
    func updateSubscriptions() async {
        activeSubscriptions.forEach { getRelayPool().closeSubscription(with: $0) }
        subscribeIfNeeded(filterForChannels)
        subscribeIfNeeded(filterForDirectMessages)

        getRelayPool().delegate = self
        getRelayPool().events
            .receive(on: DispatchQueue.main)
            .map(\.event)
            .removeDuplicates()
            .sink(receiveValue: handleIncomingEvent)
            .store(in: &cancellables)
    }

    private func subscribeIfNeeded(_ filter: Filter?) {
        guard let filter = filter else { return }
        activeSubscriptions.append(getRelayPool().subscribe(with: filter))
    }

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

    // MARK: - Event Handling
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

    // MARK: - Channel Deletion
    func submitDeleteChannelRequestForChannelId(_ channelId: String) {
        guard let account = keychainForNostr.account,
              let relatedEvents = channelEvents[channelId], !relatedEvents.isEmpty else {
            print("Error: No events found for channel deletion.")
            return
        }

        do {
            let deleteRequest = try delete(events: relatedEvents, signedBy: account)
            getRelayPool().publishEvent(deleteRequest)
        } catch {
            print("Error deleting channel: \(error.localizedDescription)")
        }
    }

    // MARK: - Messaging
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
            getRelayPool().publishEvent(event)
        } catch {
            print("Failed to publish video: \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding
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
            getRelayPool().publishEvent(message)
            defaults.set(true, forKey: key)
        } catch {
            print("Failed to send onboarding request: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.connect() }
            .store(in: &cancellables)
    }

    private func startListening() {
        NotificationCenter.default.publisher(for: .uploadVideo)
            .sink { [weak self] notification in
                guard let assetURL = notification.userInfo?["assetURL"] as? String,
                      let channelId = notification.userInfo?["channelId"] as? String else { return }
                self?.publishVideoEvent(channelId: channelId, kind: .video, content: assetURL)
            }
            .store(in: &cancellables)
    }

    // MARK: - Filters
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
}

// MARK: - Notification Names
extension Notification.Name {
    static let createdChannelForInbound = Notification.Name("createdChannelForInbound")
    static let createdChannelForOutbound = Notification.Name("createdChannelForOutbound")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
}
