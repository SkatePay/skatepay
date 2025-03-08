//
//  Network.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/27/24.
//

import os
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
    
    private var subscriptionBuffer: [String] = []
    
    var leadType = LeadType.outbound
    
    var lastEventId = ""
    
    var stopped = true
    
    private var channelEvents: [String: [NostrEvent]] = [:]
    private var activeSubscriptions: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private let keychainForNostr = NostrKeychainStorage()
    private var cancellablesFoLifecycle = Set<AnyCancellable>()
    
    let log = OSLog(subsystem: "SkateConnect", category: "Network")
    
    init() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.start() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .startNetwork)
            .sink { [weak self] _ in self?.start() }
            .store(in: &cancellablesFoLifecycle)
        
        NotificationCenter.default.publisher(for: .stopNetwork)
            .sink { [weak self] _ in self?.stop() }
            .store(in: &cancellablesFoLifecycle)
    }
    
    func start() {
        os_log("⏳ starting network", log: log, type: .info)
        
        if (!UserDefaults.standard.bool(forKey: UserDefaults.Keys.hasAcknowledgedEULA)) {
            os_log("🛑 user hasn't acknowlegdes EULA", log: log, type: .info)
            return
        }
        
        EventBus.shared.didReceiveChannelSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] channelId in
                self?.subscribeToChannelWhenReady(channelId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveDMSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] publicKey in
                self?.subscribeToUserWhenReady(publicKey)
            }
            .store(in: &cancellables)
        
        stopped = false
        
        self.connect()
        
        self.observeActions()
    }
    
    func stop() {
        os_log("⏳ stopping network", log: log, type: .info)
        
        cancellables.removeAll()
        
        guard let pool = self.relayPool else {
            os_log("🔥 relay pool is unavailable", log: log, type: .error)
            return
        }
        
        os_log("🛑 network shutting down", log: log)
        
        activeSubscriptions.forEach { pool.closeSubscription(with: $0) }
        
        pool.disconnect()
        
        stopped = true
    }

    func connect() {
        let url = Constants.RELAY_URL_SKATEPARK
        os_log("⏳ network connecting to %@", log: log, type: .info, url)
        
        do {
            relayPool = try RelayPool(relayURLs: [URL(string: url)!], delegate: self)
        } catch {
            os_log("🔥 can't initialize pool", log: log, type: .error)
        }
    }
    
    func reconnectRelaysIfNeeded() {
        guard let pool = self.relayPool else {
            os_log("🔥 relay pool is unavailable", log: log, type: .error)
            return
        }
        
        if pool.relays.count == 0 {
            self.connect()
        } else {
            pool.relays.forEach { relay in
                switch relay.state {
                case .notConnected:
                    self.connect()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Identity
extension Network {
    func needsOnboarding() -> Bool {
        guard !UserDefaults.standard.bool(forKey: UserDefaults.Keys.hasRequestedOnboardingInfo) else {
            os_log("✔️ onboarding already completed.", log: log, type: .info)
            return false
        }
        
        os_log("🛑 user needs onboarding", log: log, type: .info)
        return true
    }
    
    func requestOnboardingInfo() {
        os_log("⏳ requesting onboarding", log: log, type: .info)

        if (!needsOnboarding()) {
            return
        }
        
        var account = keychainForNostr.account // Create a mutable variable

        if account == nil {
            os_log("🔥 can't get account", log: log, type: .error)
            account = createIdentity() // ✅ Assign the new identity
        }

        guard let validAccount = account else {
            os_log("🔥 can't create identity", log: log, type: .error)
            return
        }
        
        guard let publicKey = PublicKey(npub: AppData().getSupport().npub) else {
            os_log("🔥 can't get suport account", log: log, type: .error)
            return
        }
        
        do {
            let text = "I'm online."
            let contentStructure = ContentStructure(content: text, kind: .hidden)
            let jsonData = try JSONEncoder().encode(contentStructure)
            let content = String(data: jsonData, encoding: .utf8) ?? text
            
            let message = try legacyEncryptedDirectMessage(
                withContent: content,
                toRecipient: publicKey,
                signedBy: validAccount
            )
            
            self.relayPool?.publishEvent(message)
            UserDefaults.standard.set(true, forKey: UserDefaults.Keys.hasRequestedOnboardingInfo)
        } catch {
            os_log("🔥 failed to request obboarding", log: log, type: .error)
        }
    }
    
    private func createIdentity() -> Keypair? {
        do {
            if (keychainForNostr.account == nil) {
                let keypair = Keypair()!
                try keychainForNostr.save(keypair)
                return keypair
            }
        } catch {
            os_log("🔥 identity error %@", log: log, type: .error, error.localizedDescription)
        }
        return nil
    }
}

// MARK: - Relay Delegate
extension Network {
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        switch relay.state {
        case .connected:
            os_log("🚀 network connected", log: log, type: .info)
            self.connected = true
            self.processSubscriptionBuffer()
            self.requestOnboardingInfo()
        case .notConnected:
            os_log("⏳ reconnecting to relay: %@", log: log, type: .info, relay.url.absoluteString)
        case .error(let error):
            os_log("🔥 network error %@", log: log, type: .error, error.localizedDescription)
            
            if (stopped) {
                return
            }
            
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
            self.handleRelayEvent(event)
        }
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            
            os_log("📩 EOSE received %@", log: self.log, type: .info, subscriptionId)
            
            DispatchQueue.main.async {
                EventBus.shared.didReceiveEOSE.send(response)
            }
        }
    }
}

// MARK: - Default Subscriptions
extension Network {
    private var filterForChannels: Filter? {
        guard let account = keychainForNostr.account else {
            return nil
        }
        let filter = Filter(authors: [account.publicKey.hex], kinds: [EventKind.channelCreation.rawValue])
        return filter
    }
    
    private var filterForDirectMessages: Filter? {
        guard let account = keychainForNostr.account else {
            return nil
        }
        let filter = Filter(kinds: [
            EventKind.legacyEncryptedDirectMessage.rawValue,
            EventKind.channelCreation.rawValue
        ], tags: ["p" : [account.publicKey.hex]])
        return filter
    }
    
    func addDefaultSubscriptions() {
        os_log("⏳ adding default subscriptions", log: log, type: .info)
        
        if let filter = filterForChannels {
            guard let subscription = subscribeIfNeeded(filter) else {
                os_log("🔥 subscription is unavailable", log: log, type: .error)
                return
            }
            os_log("🔍 channels: %@", log: log, type: .info, subscription)
        }
        
        if let filter = filterForDirectMessages {
            guard let subscription = subscribeIfNeeded(filter) else {
                os_log("🔥 subscription is unavailable", log: log, type: .error)
                return
            }
            os_log("🔍 dms: %@", log: log, type: .info, subscription)
        }
    }
}

// MARK: - Channel Subscription Methods
extension Network {
    func subscribeToChannelWhenReady(_ channelId: String) {
        if connected {
            subscribeToChannel(channelId)
        } else {
            os_log("🔍 channelId: %@", log: log, type: .info, channelId)
            subscriptionBuffer.append(channelId)
        }
    }
    
    private func processSubscriptionBuffer() {
        os_log("⏳ processing queued channel subscriptions (%d)", log: log, type: .info, subscriptionBuffer.count)
        
        for channelId in subscriptionBuffer {
            subscribeToChannel(channelId)
        }
        
        subscriptionBuffer.removeAll()
        
        addDefaultSubscriptions()
    }
    
    private func subscribeIfNeeded(_ filter: Filter) -> String? {
        guard let pool = self.relayPool else {
            print("🔥 relaypool is unavailable")
            return nil
        }
        
        let subscription = pool.subscribe(with: filter)
        activeSubscriptions.append(subscription)
        return subscription
    }
    
    private func subscribeToChannel(_ channelId: String) {
        os_log("⏳ adding subscription to channel [%@]", log: log, type: .info, channelId)
        
        let filterForMetadata = Filter(
            ids: [channelId],
            kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue]
        )!
        let filterForFeed = Filter(
            kinds: [EventKind.channelMessage.rawValue],
            tags: ["e": [channelId]],
            limit: 32
        )!
        
        let subscriptionIdForMetadata = subscribeIfNeeded(filterForMetadata)
        let subscriptionIdForMessages = subscribeIfNeeded(filterForFeed)
        
        os_log("✔️ Subscribed to new channel: %@", log: log, type: .info, channelId)
        
        if let subscription = subscriptionIdForMetadata {
            EventBus.shared.didReceiveChannelSubscription.send((channelId, subscription))
            os_log("🔍 metadata: %@", log: log, type: .info, subscription)
        }
        
        if let subscription = subscriptionIdForMessages {
            EventBus.shared.didReceiveChannelSubscription.send((channelId, subscription))
            os_log("🔍 messages: %@", log: log, type: .info, subscription)
        }
    }
}

// MARK: - DM Subscription Methods
extension Network {
    private func subscribeToUserWhenReady(_ publicKey: PublicKey) {
        if connected {
            subscribeToUser(publicKey)
        } else {
            os_log("🔍 publicKey: %@", log: log, type: .info, publicKey.npub)
        }
    }
    
    func subscribeToUser(_ publicKey: PublicKey) {
        os_log("⏳ adding subscription to user [%@]", log: log, type: .info, publicKey.npub)
        
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        let authors = [publicKey.hex, account.publicKey.hex]
        let filter = Filter(authors: authors, kinds: [4], tags: ["p": authors], limit: 64)!
        
        let subscriptionIdForMessages = subscribeIfNeeded(filter)
        
        os_log("✔️ Subscribed to new user: %@", log: log, type: .info, publicKey.npub)
        
        if let subscription = subscriptionIdForMessages {
            EventBus.shared.didReceiveDMSubscription.send((publicKey, subscription))
            os_log("🔍 messages: %@", log: log, type: .info, subscription)
        }
    }
}

// MARK: - Event Handlers
extension Network {
    private func handleRelayEvent(_ event: RelayEvent) {
        switch event.event.kind {
        case .channelCreation: handleChannelCreation(event)
        case .legacyEncryptedDirectMessage: handleDirectMessage(event)
        case .channelMessage: handleChannelMessage(event)
        default: print("Unhandled event: \(event.subscriptionId) \(event.event.kind)")
        }
    }
    
    private func handleChannelCreation(_ event: RelayEvent) {
        channelEvents[event.event.id, default: []].append(event.event)
        
        NotificationCenter.default.post(
            name: leadType == .outbound ? .createdChannelForOutbound : .createdChannelForInbound,
            object: event
        )
        
        EventBus.shared.didReceiveChannelMetadata.send(event)
    }
    private func handleChannelMessage(_ event: RelayEvent) {
        NotificationCenter.default.post(name: .receivedChannelMessage, object: event.event)
        
        EventBus.shared.didReceiveChannelMessage.send(event)
    }
    
    private func handleDirectMessage(_ event: RelayEvent) {
        NotificationCenter.default.post(name: .receivedDirectMessage, object: event.event)
        
        EventBus.shared.didReceiveDMMessage.send(event)
    }
}

// MARK: - Publishers
extension Network {
    func publishVideoEvent(channelId: String, kind: Kind = .message, content: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
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
            os_log("🔥 failed to publish video", log: log, type: .error)
        }
    }
    
    func publishChannelEvent(channelId: String, kind: Kind = .message, content: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
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
            os_log("🔥 failed to publish channel event", log: log, type: .error)
        }
    }
    
    func publishDMEvent(pubKey: PublicKey, kind: Kind = .message, content: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        do {
            let contentStructure = ContentStructure(content: content, kind: .message)
            let jsonData = try JSONEncoder().encode(contentStructure)
            let content = String(data: jsonData, encoding: .utf8) ?? content

            let directMessage = try legacyEncryptedDirectMessage(
                withContent: content,
                toRecipient: pubKey,
                signedBy: account
            )
            self.relayPool?.publishEvent(directMessage)
        } catch {
            os_log("🔥 failed to publish dm event", log: log, type: .error)
        }
    }
    
    func publishDeleteEventForChannel(_ channelId: String) {
        guard let account = keychainForNostr.account,
              let relatedEvents = channelEvents[channelId], !relatedEvents.isEmpty else {
            print("Error: No events found for channel deletion.")
            return
        }
        
        do {
            let deleteRequest = try delete(events: relatedEvents, signedBy: account)
            self.relayPool?.publishEvent(deleteRequest)
        } catch {
            os_log("🔥 failed to delete channel", log: log, type: .error)
        }
    }
}

// MARK: - Observers
extension Network {
    private func observeActions() {
        // Other
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

// MARK: - Notification Names
extension Notification.Name {
    static let startNetwork = Notification.Name("startNetwork")
    static let stopNetwork = Notification.Name("stopNetwork")
    
    static let createdChannelForInbound = Notification.Name("createdChannelForInbound")
    static let createdChannelForOutbound = Notification.Name("createdChannelForOutbound")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
}
