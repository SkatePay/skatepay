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


struct Subscription {
    let id: String
    let type: SubscriptionType
}

enum SubscriptionType {
    case channel
    case directMessage
}

struct ChannelSubscriptionKey: Hashable {
    let channelId: String
    let kind: EventKind
}

class Network: ObservableObject, RelayDelegate, EventCreating {
    let log = OSLog(subsystem: "SkateConnect", category: "Network")
    
    @Published var relayPool: RelayPool?
    @Published var connected = false
    
    var stopped = true
    var subscriptionCount = 0
    
    private var processedEvents = Set<String>()
    
    // Favorites
    private var favoriteUserSubscriptions = Set<String>()
    private var channelCreation: [String: Channel] = [:]
    private var channelMetadata: [String: ChannelMetadata] = [:]
    
    private var favoriteChannelSubscriptions = Set<String>()
    //
    
    // Channels
    private var channelSubscriptions: [ChannelSubscriptionKey: Subscription] = [:]
    private var channelSubscriptionBuffer = [EventKind: [String]]()
    
    // Users
    private var userMessagesSubscriptions = [String: Subscription]()
    
    private var subscriptionIdToEntity = [String: String]() // Reverse lookup
    
    var leadType = ChannelType.outbound
    
    var lastEventId = ""
    
    // DeepLink
    var cachedChannelId: String?
    
    private var cancellablesFoLifecycle = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()
    
    private let keychainForNostr = NostrKeychainStorage()
    
    init() {
        os_log("🚀🚀🚀🚀🚀", log: log, type: .info)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.start() }
            .store(in: &cancellablesFoLifecycle)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.backupActiveSession()
            }
            .store(in: &cancellablesFoLifecycle)
        
        NotificationCenter.default.publisher(for: .startNetwork)
            .sink { [weak self] _ in self?.start() }
            .store(in: &cancellablesFoLifecycle)
        
        NotificationCenter.default.publisher(for: .stopNetwork)
            .sink { [weak self] _ in self?.stop() }
            .store(in: &cancellablesFoLifecycle)
        
        
        EventBus.shared.didReceiveChannelSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                let kind = request.kind
                let channelId = request.channelId
                
                if kind == .channelCreation {
                    self?.subscribeToChannelCreationWhenReady(channelId)
                } else if kind == .channelMetadata {
                    let filter = Filter(kinds: [
                        kind.rawValue,
                    ], tags: ["e" : [channelId]])!
                    
                    self?.subscribeToChanneEvents(channelId, kind: kind, filter: filter)
                } else if request.kind == .channelMessage {
                    self?.subscribeToChannelMessagesWhenReady(channelId)
                }
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveDMSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] publicKey in
                self?.subscribeToUserWhenReady(publicKey)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveCloseMetadataSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (subscriptionId, kind) in
                guard let pool = self?.relayPool else {
                    return
                }
                
                pool.closeSubscription(with: subscriptionId)
                                
                self?.subscriptionCount -= 1
                
                if let channelId = self?.subscriptionIdToEntity[subscriptionId] {
                    self?.removeSubscription(for: channelId, kind: kind)
                }
                self?.subscriptionIdToEntity.removeValue(forKey: subscriptionId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveCloseMessagesSubscriptionRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscriptionId in
                guard let pool = self?.relayPool else {
                    return
                }
                
                pool.closeSubscription(with: subscriptionId)
                                
                self?.subscriptionCount -= 1
                self?.subscriptionIdToEntity.removeValue(forKey: subscriptionId)
            }
            .store(in: &cancellables)
        
        self.connectPublishers()
    }
    
    func backupActiveSession() {
        os_log("🔄 backupActiveSession", log: log, type: .info)
        //        stop()
    }
    
    func start() {
        os_log("⏳ starting network", log: log, type: .info)
        
        if (!UserDefaults.standard.bool(forKey: UserDefaults.Keys.hasAcknowledgedEULA)) {
            os_log("🛑 user hasn't acknowlegdes EULA", log: log, type: .info)
            return
        }
        
        stopped = false
        
        self.connect()
    }
    
    func stop() {
        os_log("⏳ stopping network", log: log, type: .info)
        
        guard let pool = self.relayPool else {
            os_log("🔥 relay pool is unavailable", log: log, type: .error)
            return
        }
        
        os_log("🛑 network shutting down", log: log)
        
        channelSubscriptions.removeAll()
        
        userMessagesSubscriptions.removeAll()
        
        subscriptionIdToEntity.keys.forEach { pool.closeSubscription(with: $0) }
        subscriptionIdToEntity.removeAll()
        
        favoriteChannelSubscriptions.removeAll()
        favoriteUserSubscriptions.removeAll()
        
        processedEvents.removeAll()
        
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
            processFavorites()
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
            let contentStructure = ContentStructure(kind: .hidden, text: text, content: text)
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
            
            DispatchQueue.main.async {
                self.connected = true
            }
            
            self.processFavorites()
            self.processSubscriptionBuffers()
            self.requestOnboardingInfo()
            self.processDeeplinkAction()
        case .notConnected:
            os_log("⏳ reconnecting to relay: %@", log: log, type: .info, relay.url.absoluteString)
        case .error(let error):
            os_log("🔥 network error %@", log: log, type: .error, error.localizedDescription)
            
            if (stopped) {
                return
            }
            
            DispatchQueue.main.async {
                self.connected = false
            }
            
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
            
            if (self.favoriteChannelSubscriptions.contains(subscriptionId)) {
                return
            }
            
            if (self.favoriteUserSubscriptions.contains(subscriptionId)) {
                return
            }
            
            os_log("📩 EOSE received %@", log: self.log, type: .info, subscriptionId)
            
            EventBus.shared.didReceiveEOSE.send(response)
        }
    }
}

// MARK: - Favorite Subscriptions
extension Network {
    private var filterForMyChannels: Filter? {
        guard let account = keychainForNostr.account else {
            return nil
        }
        let filter = Filter(authors: [account.publicKey.hex], kinds: [
            EventKind.channelCreation.rawValue,
            EventKind.channelMetadata.rawValue
        ])
        return filter
    }
    
    private var filterForIncomingDirectMessages: Filter? {
        guard let account = keychainForNostr.account else {
            return nil
        }
        let filter = Filter(kinds: [
            EventKind.legacyEncryptedDirectMessage.rawValue,
        ], tags: ["p" : [account.publicKey.hex]])
        return filter
    }
    
    func processFavorites() {
        os_log("⏳ processing favorites", log: log, type: .info)
        
        guard let pool = self.relayPool else {
            os_log("🔥 relay pool is unavailable", log: log, type: .error)
            return
        }
        
        favoriteChannelSubscriptions.forEach { pool.closeSubscription(with: $0) }
        
        if let filter = filterForMyChannels {
            guard let subscriptionId = subscribeIfNeeded(filter) else {
                os_log("🔥 error subscribing", log: log, type: .error)
                return
            }
            
            favoriteChannelSubscriptions.insert(subscriptionId)
            os_log("✔️ favorite channels subscription: %@", log: log, type: .info, subscriptionId)
        }
        
        
        favoriteUserSubscriptions.forEach { pool.closeSubscription(with: $0) }
        
        if let filter = filterForIncomingDirectMessages {
            guard let subscriptionId = subscribeIfNeeded(filter) else {
                os_log("🔥 error subscribinmg", log: log, type: .error)
                return
            }
            favoriteUserSubscriptions.insert(subscriptionId)
            os_log("✔️ favorite users subscription: %@", log: log, type: .info, subscriptionId)
        }
    }
    
    func setCachedChannelId(_ channelId: String) {
        cachedChannelId = channelId
    }
    
    func processDeeplinkAction() {
        os_log("⏳ processing deeplink action", log: log, type: .info)
        
        guard let channelId = cachedChannelId else {
            os_log("🛑 no cachedChanneld was set", log: log, type: .info)
            return
        }
        
        NotificationCenter.default.post(
            name: .subscribeToChannel,
            object: self,
            userInfo: ["channelId": channelId]
        )
        
        cachedChannelId = nil
    }
}

// MARK: - Channel Subscription Methods
extension Network {
    private func getSubscription(for channelId: String, kind: EventKind) -> Subscription? {
        let key = ChannelSubscriptionKey(channelId: channelId, kind: kind)
        return channelSubscriptions[key]
    }
    
    private func setSubscription(_ subscription: Subscription, for channelId: String, kind: EventKind) {
        let key = ChannelSubscriptionKey(channelId: channelId, kind: kind)
        channelSubscriptions[key] = subscription
        
        EventBus.shared.didReceiveChannelSubscription.send((key, subscription.id))
    }
    
    private func removeSubscription(for channelId: String, kind: EventKind) {
        let key = ChannelSubscriptionKey(channelId: channelId, kind: kind)
        channelSubscriptions.removeValue(forKey: key)
    }
    
    func subscribeToChannelCreationWhenReady(_ channelId: String) {
        if connected {
            let kind = EventKind.channelCreation
            let filter = Filter(
                ids: [channelId],
                kinds: [kind.rawValue]
            )!
            
            subscribeToChanneEvents(channelId, kind: kind, filter: filter)
        } else {
            os_log("🔍 channelId: %@", log: log, type: .info, channelId)
            channelSubscriptionBuffer[.channelCreation, default: []].append(channelId)
        }
    }
    
    func subscribeToChannelMessagesWhenReady(_ channelId: String) {
        if connected {
            let kind = EventKind.channelMessage
            let filter = Filter(
                kinds: [kind.rawValue],
                tags: ["e": [channelId]],
                limit: 64
            )!
            
            subscribeToChanneEvents(channelId, kind: kind, filter: filter)
        } else {
            os_log("🔍 channelId: %@", log: log, type: .info, channelId)
            channelSubscriptionBuffer[.channelMessage, default: []].append(channelId)
        }
    }
    
    private func processSubscriptionBuffers() {
        for (kind, channelIds) in channelSubscriptionBuffer {
            os_log("⏳ processing channels [%@] queue (%d)", log: log, type: .info, String(describing: kind), channelIds.count)
            
            for channelId in channelIds {
                switch kind {
                case .channelCreation:
                    let filter = Filter(
                        ids: [channelId],
                        kinds: [EventKind.channelCreation.rawValue]
                    )!
                    
                    subscribeToChanneEvents(channelId, kind: kind, filter: filter)
                case .channelMessage:
                    let kind = EventKind.channelMessage
                    let filter = Filter(
                        kinds: [kind.rawValue],
                        tags: ["e": [channelId]],
                        limit: 64
                    )!
                    
                    subscribeToChanneEvents(channelId, kind: kind, filter: filter)
                default:
                    os_log("⚠️ unhandled buffer kind: %@", log: log, type: .error, String(describing: kind))
                }
            }
            channelSubscriptionBuffer[kind] = []
        }
    }
    
    private func subscribeIfNeeded(_ filter: Filter) -> String? {
        guard let pool = self.relayPool else {
            print("🔥 relaypool is unavailable")
            return nil
        }
        
        let subscriptionId = pool.subscribe(with: filter)
        
        subscriptionCount += 1
        
        os_log("📊 subscriptionCount=%@", log: log, type: .info, "\(subscriptionCount)")
        
        return subscriptionId
    }
    
    private func subscribeToChanneEvents(_ channelId: String, kind: EventKind, filter: Filter) {
        if !connected {
            os_log("⏳ adding subscription to %@ buffer for [%@]", log: log, type: .info, String(describing: kind), channelId)
            channelSubscriptionBuffer[kind, default: []].append(channelId)
            return
        }
        
        os_log("⏳ subscribing to %@ [%@]", log: log, type: .info, String(describing: kind), channelId)
        
        if let subscription = getSubscription(for: channelId, kind: kind) {
            os_log("🔄 Resubscribing to %@: %@ with existing subscription: %@", log: log, type: .info, String(describing: kind), channelId, subscription.id)
            relayPool?.closeSubscription(with: subscription.id)
            removeSubscription(for: channelId, kind: kind)
            
            subscriptionIdToEntity.removeValue(forKey: subscription.id)
        }
        
        if let subscriptionId = subscribeIfNeeded(filter) {
            let subscription = Subscription(id: subscriptionId, type: .channel)
            setSubscription(subscription, for: channelId, kind: kind)
            subscriptionIdToEntity[subscriptionId] = channelId
            
            os_log("✔️ Subscribed to %@ %@ with subscriptionId %@", log: log, type: .info, String(describing: kind), channelId, subscriptionId)
        }
    }
}

// MARK: - User Subscription Methods
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
        
        // Messages
        if let subscription = userMessagesSubscriptions[publicKey.hex] {
            os_log("🔄 Resubscribing to user messages: %@ with existing subscription: %@", log: log, type: .info, publicKey.hex, subscription.id)
            relayPool?.closeSubscription(with: subscription.id)
            userMessagesSubscriptions.removeValue(forKey: publicKey.hex)
            subscriptionIdToEntity.removeValue(forKey: subscription.id)
        }
        
        let authors = [publicKey.hex, account.publicKey.hex]
        let filter = Filter(authors: authors, kinds: [4], tags: ["p": authors], limit: 32)!
        
        if let subscriptionId = subscribeIfNeeded(filter) {
            EventBus.shared.didReceiveDMSubscription.send((publicKey, subscriptionId))
            
            let subscription = Subscription(id: subscriptionId, type: .directMessage)
            
            userMessagesSubscriptions[publicKey.hex] = subscription
            subscriptionIdToEntity[subscriptionId] = publicKey.hex
            
            os_log("✔️ Subscribed to user messages %@ with subscriptionId %@", log: log, type: .info, publicKey.hex, subscriptionId)
        }
    }
}

// MARK: - Event Handlers
extension Network {
    private func handleRelayEvent(_ event: RelayEvent) {
        if (favoriteUserSubscriptions.contains(event.subscriptionId) || favoriteChannelSubscriptions.contains(event.subscriptionId)) {
            if (!processedEvents.contains(event.event.id)) {
                processedEvents.insert(event.event.id)
                
                switch event.event.kind {
                case .legacyEncryptedDirectMessage: handleDirectMessage(event)
                case .channelCreation: handleChannelCreation(event)
                case .channelMetadata: handleChannelMetadataForOutbound(event)
                case .channelMessage: handleChannelMessage(event)
                default: return
                }
            } else {
                os_log("🛑 dropping event", log: log, type: .info)
                // Will address in 1.7, need a better way to snooze previosly processed events
            }
        } else {
            switch event.event.kind {
            case .legacyEncryptedDirectMessage: EventBus.shared.didReceiveDMMessage.send(event)
            case .channelCreation: EventBus.shared.didReceiveChannelData.send(event)
            case .channelMetadata: handleChannelMetadata(event)
            case .channelMessage: EventBus.shared.didReceiveChannelMessage.send(event)
            default: return
            }
        }
    }
    
    private func handleChannelCreation(_ event: RelayEvent) {
        let channelId = event.event.id
        
        channelCreation[channelId] = parseChannel(from: event.event)
        
        NotificationCenter.default.post(
            name: leadType == .outbound ? .createdChannelForOutbound : .createdChannelForInbound,
            object: event.event
        )
    }
    
    private func handleChannelMetadataForOutbound(_ event: RelayEvent) {
        guard let data = event.event.content.data(using: .utf8) else {
            os_log("🔥 failed to parse data", log: log, type: .error)
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let newMetadata = try decoder.decode([String: ChannelMetadata].self, from: data)
            
            self.channelMetadata.merge(newMetadata) { (_, new) in new }
            
            for (channelId, metadata) in self.channelMetadata {
                if var channel = self.channelCreation[channelId]{
                    channel.metadata = metadata
                    self.channelCreation[channelId] = channel
                    MainHelper.updateLead(for: channel)
                }
            }
        } catch {
            os_log("🔥 decoding error: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func handleChannelMetadata(_ event: RelayEvent) {
        guard let data = event.event.content.data(using: .utf8) else {
            os_log("🔥 failed to parse data", log: log, type: .error)
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let newMetadata = try decoder.decode([String: ChannelMetadata].self, from: data)
            
            self.channelMetadata.merge(newMetadata) { (_, new) in new }
            
            for (channelId, metadata) in self.channelMetadata {
                if var channel = self.channelCreation[channelId]{
                    channel.metadata = metadata
                    self.channelCreation[channelId] = channel
                    MainHelper.updateLead(for: channel)
                }
                
                EventBus.shared.didReceiveChannelMetadata.send((channelId: channelId, metadata: metadata))
            }
        } catch {
            os_log("🔥 decoding error: %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    private func handleChannelMessage(_ event: RelayEvent) {
        NotificationCenter.default.post(name: .receivedChannelMessage, object: event.event)
    }
    
    private func handleDirectMessage(_ event: RelayEvent) {
        NotificationCenter.default.post(name: .receivedDirectMessage, object: event.event)
    }
}

// MARK: - Publishers
extension Network {
    func publishChannelEvent(channelId: String, kind: Kind = .message, text: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        do {
            let contentStructure = ContentStructure(kind: kind, text: text, content: text)
            let encoder = JSONEncoder()
            let data = try encoder.encode(contentStructure)
            let contentString = String(data: data, encoding: .utf8) ?? text
            
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
    
    func publishDMEvent(publicKey: PublicKey, kind: Kind = .message, text: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        do {
            let contentStructure = ContentStructure(kind: kind, text: text, content: text)
            let jsonData = try JSONEncoder().encode(contentStructure)
            let content = String(data: jsonData, encoding: .utf8) ?? text
            
            let directMessage = try legacyEncryptedDirectMessage(
                withContent: content,
                toRecipient: publicKey,
                signedBy: account
            )
            self.relayPool?.publishEvent(directMessage)
        } catch {
            os_log("🔥 failed to publish dm event", log: log, type: .error)
        }
    }
    
    func publishVideoEvent(channelId: String, kind: Kind = .message, text: String) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        do {
            let contentStructure = ContentStructure(kind: kind, text: text, content: text)
            let encodedContent = String(data: try JSONEncoder().encode(contentStructure), encoding: .utf8) ?? text
            
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
    
    func publishDeleteEventForChannel(_ channelId: String) {
        guard let account = keychainForNostr.account,
              let event = channelCreation[channelId]?.creationEvent else {
            os_log("🔥 Error: No events found for channel deletion.", log: log, type: .error)
            return
        }
        
        do {
            let deleteRequest = try delete(events: [event], signedBy: account)
            self.relayPool?.publishEvent(deleteRequest)
            
            self.channelCreation.removeValue(forKey: channelId)
            self.channelMetadata.removeValue(forKey: channelId)
            self.removeSubscription(for: channelId, kind: .channelCreation)
            self.removeSubscription(for: channelId, kind: .channelMetadata)
            self.removeSubscription(for: channelId, kind: .channelMessage)
        } catch {
            os_log("🔥 failed to delete channel", log: log, type: .error)
        }
    }
}

// MARK: - Observers
extension Network {
    private func connectPublishers() {
        NotificationCenter.default.publisher(for: .uploadVideo)
            .sink { [weak self] notification in
                guard let assetURL = notification.userInfo?["assetURL"] as? String,
                      let channelId = notification.userInfo?["channelId"] as? String else { return }
                self?.publishVideoEvent(channelId: channelId, kind: .video, text: assetURL)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .publishChannelEvent)
            .sink { [weak self] notification in
                guard let channelId = notification.userInfo?["channelId"] as? String,
                      let content = notification.userInfo?["content"] as? String,
                      let kind = notification.userInfo?["kind"] as? Kind else { return }
                self?.publishChannelEvent(channelId: channelId, kind: kind, text: content)
                
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .publishDMEvent)
            .sink { [weak self] notification in
                guard let npub = notification.userInfo?["npub"] as? String,
                      let content = notification.userInfo?["content"] as? String,
                      let kind = notification.userInfo?["kind"] as? Kind else { return }
                
                guard let publicKey = PublicKey(npub: npub) else { return }
                
                self?.publishDMEvent(publicKey: publicKey, kind: kind, text: content)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .saveChannelMetadata)
            .sink { [weak self] notification in
                guard let channel = notification.userInfo?["channel"] as? Channel else { return }
                
                self?.saveChannel(channel)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Channel
extension Network {
    func saveChannel(_ channel: Channel) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        guard let channelId = channel.creationEvent?.id else { return }
        
        channelMetadata[channelId] = channel.metadata
        
        do {
            
            let metadataKeys = Array(channelMetadata.keys)
            
            let tags = metadataKeys.map { key in
                return try! EventTag(eventId: key)
            }
            
            // Convert channelMetadata dictionary to JSON data using JSONEncoder
            let jsonData = try JSONEncoder().encode(channelMetadata)
            
            // Convert JSON data to a string
            let content = String(data: jsonData, encoding: .utf8) ?? ""
            
            let builder = SetChannelMetadataEvent.Builder()
                .content(content)
                .appendTags(contentsOf: tags.map { $0.tag })
            
            let event = try builder.build(signedBy: account)
            
            self.relayPool?.publishEvent(event)
        } catch {
            os_log("🔥 error publishing metadata %@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func deleteEvent(_ event: NostrEvent) {
        guard let account = keychainForNostr.account else {
            os_log("🔥 account is unavailable", log: log, type: .error)
            return
        }
        
        do {
            let deletionEvent = try delete(
                events: [event],
                signedBy: account
            )
            self.relayPool?.publishEvent(deletionEvent)
        } catch {
            os_log("🔥 error deleting message %@", log: log, type: .error, error.localizedDescription)
        }
    }
}

// Public helpers
extension Network {
    func getChannel(for channelId: String) -> Channel? {
        return channelCreation[channelId]
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startNetwork = Notification.Name("startNetwork")
    static let stopNetwork = Notification.Name("stopNetwork")
    
    // Event handling
    static let createdChannelForInbound = Notification.Name("createdChannelForInbound")
    static let createdChannelForOutbound = Notification.Name("createdChannelForOutbound")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
    
    // Camera
    static let didFinishRecordingTo = Notification.Name("didFinishRecordingTo")
    
    // Location
    static let markSpot = Notification.Name("markSpot")
    static let updateSpot = Notification.Name("updateSpot")
    
    static let goToLandmark = Notification.Name("goToLandmark")
    static let goToCoordinate = Notification.Name("goToCoordinate")
    static let goToSpot = Notification.Name("goToSpot")
    static let barcodeScanned = Notification.Name("barcodeScanned")
    
    // Uploads
    static let didFinishUpload = Notification.Name("didFinishUpload")
    static let uploadImage = Notification.Name("uploadImage")
    static let uploadVideo = Notification.Name("uploadVideo")
    
    // Channels
    static let saveChannelMetadata = Notification.Name("saveChannelMetadata")
    static let subscribeToChannel = Notification.Name("subscribeToChannel")
    static let muteUser = Notification.Name("muteUser")
    
    // Publish
    static let publishChannelEvent = Notification.Name("publishChannelEvent")
    static let publishDMEvent = Notification.Name("publishDMEvent")
}
