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

func shareVideo(_ videoUrl: URL) {
    // Implementation for sharing the video
    print("Sharing video URL: \(videoUrl)")

    if let url = URL(string: videoUrl.absoluteString) {
        let fileNameWithoutExtension = url.deletingPathExtension().lastPathComponent
        print("File name without extension: \(fileNameWithoutExtension)")
        
        // Construct the custom URL
        let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/video/\(fileNameWithoutExtension)"
        
        // Ensure it's a valid URL
        if let customUrl = URL(string: customUrlString) {
            print("Custom URL: \(customUrl)")
            
            // Open the custom URL
            if UIApplication.shared.canOpenURL(customUrl) {
                UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
            } else {
                print("Unable to open URL: \(customUrl)")
            }
        } else {
            print("Invalid custom URL")
        }
    }
}

func shareChannel(_ channelId: String) {
    // Implementation for sharing channel
    print("Sharing channel with id: \(channelId)")
    
    // Construct the custom URL
    let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/channel/\(channelId)"
    
    // Ensure it's a valid URL
    if let customUrl = URL(string: customUrlString) {
        print("Custom URL: \(customUrl)")
        
        // Open the custom URL
        if UIApplication.shared.canOpenURL(customUrl) {
            UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
        } else {
            print("Unable to open URL: \(customUrl)")
        }
    } else {
        print("Invalid custom URL")
    }
}

class Network: ObservableObject, RelayDelegate, EventCreating {
    @Published var relayPool: RelayPool?
    
    // A map to store channel-related events by channel ID
    private var channelEvents: [String: [NostrEvent]] = [:]
    
    private var activeSubscriptions: [String] = []
    private var eventsCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    var leadType = LeadType.outbound
    
    let keychainForNostr = NostrKeychainStorage()
        
    init() {
        connect()
        
        // Observe app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // Reconnect when the app comes back to the foreground
                self?.connect()
            }
            .store(in: &cancellables)
        
        startListening()
    }
    
    func connect() {
        do {
            self.relayPool = try RelayPool(relayURLs: [
                URL(string: Constants.RELAY_URL_SKATEPARK)!], delegate: self)
        } catch {
            print("Error initializing RelayPool: \(error)")
        }
    }
    
    func getRelayPool() -> RelayPool {
        self.reconnectRelaysIfNeeded()
        return relayPool!
    }
    
    func reconnectRelaysIfNeeded() {
        guard let relays = relayPool?.relays else {
            return
        }
        
        for (_, relay) in relays.enumerated() {
            switch relay.state {
            case .notConnected:
                print("Attempting to reconnect to relay: \(relay.url)")
            case .connecting:
                print("Relay is currently connecting. Please wait.")
            case .connected:
                continue
            case .error(let error):
                print("An error occurred with the relay: \(error.localizedDescription)")
                
                if error.localizedDescription == "The operation couldn’t be completed. Socket is not connected" ||
                    error.localizedDescription == "The Internet connection appears to be offline." {
                    self.connect()
                }
            }
        }
    }
    
    // MARK: - RelayDelegate
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        switch state {
        case .connected:
            Task {
                await self.updateSubscriptions()
            }
        case .notConnected:
            return
        case .connecting:
            return
        case .error(_):
            return
        }
    }
    func relay(_ relay: Relay, didReceive event: RelayEvent) {}
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
        }
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
    
    // MARK: - Subscriptions
    func updateSubscriptions() async {
        // Close existing subscriptions if necessary
        for subscription in activeSubscriptions {
            getRelayPool().closeSubscription(with: subscription)
        }
        
        // Set up new subscriptions based on provided filters
        if let unwrappedFilter = filterForChannels {
            let newSubscription = getRelayPool().subscribe(with: unwrappedFilter)
            activeSubscriptions.append(newSubscription)
        }
        
        if let unwrappedFilter = filterForDirectMessages {
            let newSubscription = getRelayPool().subscribe(with: unwrappedFilter)
            activeSubscriptions.append(newSubscription)
        }
        
        getRelayPool().delegate = self
        
        eventsCancellable = getRelayPool().events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink(receiveValue: handleIncomingEvent)
    }
    
    // Function to handle relay events
    private func handleIncomingEvent(_ event: NostrEvent) {
        if event.kind == .channelCreation {
            // Collect events by channelId
            let channelId = event.id
            var events = channelEvents[channelId] ?? []
            events.append(event)
            channelEvents[channelId] = events
        }
        
        switch event.kind {
        case .channelCreation:
            handleChannelCreation(event)
        case .legacyEncryptedDirectMessage:
            handleDirectMessage(event)
        case .channelMessage:
            handleChannelMessage(event)
        default:
            print("Unhandled event kind: \(event.kind)")
        }
    }
    
    // MARK: - Notifications
    // Process channel creation event
    private func handleChannelCreation(_ event: NostrEvent) {
        if (self.leadType == LeadType.outbound) {
            NotificationCenter.default.post(name: .createdChannelForOutbound, object: event)
        } else {
            NotificationCenter.default.post(name: .createdChannelForInbound, object: event)
        }
    }
    
    // Process direct message event
    private func handleDirectMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedDirectMessage, object: event)
    }
    
    // Process channel message event
    private func handleChannelMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedChannelMessage, object: event)
    }
    
    // MARK: - Public Methods
    func requestOnboardingInfo() async {
        let defaults = UserDefaults.standard
        let hasRequestedOnboardingInfo = "hasRequestedOnboardingInfo"
        
        // Check if the function has run before
        if !defaults.bool(forKey: hasRequestedOnboardingInfo) {
            guard let account = keychainForNostr.account else {
                print("Error: Failed to create Filter")
                return
            }
            
            guard let recipientPublicKey = PublicKey(npub: AppData().getSupport().npub) else {
                print("Failed to create PublicKey from npub.")
                return
            }
            
            let content = "I'm online."
            do {
                let directMessage = try legacyEncryptedDirectMessage(withContent: content,
                                                                     toRecipient: recipientPublicKey,
                                                                     signedBy: account)
                getRelayPool().publishEvent(directMessage)
                defaults.set(true, forKey: hasRequestedOnboardingInfo)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Onboarding info request has already been sent.")
        }
    }
    
    // MARK: - Channel Deletion
    func submitDeleteChannelRequestForChannelId(_ channelId: String) {
        guard let account = keychainForNostr.account else {
            print("Error: Failed to create Filter")
            return
        }
        
        // Fetch all related channel events
        guard let relatedEvents = channelEvents[channelId], !relatedEvents.isEmpty else {
            print("No events found for the channel.")
            return
        }
        
        do {
            let channelDeletionRequest = try delete(events: relatedEvents, signedBy: account)
            getRelayPool().publishEvent(channelDeletionRequest)
        } catch {
            print("Error creating or publishing channel deletion request: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Post Nostr Event
    public func publishVideoEvent(channelId: String, kind: Kind = .message, content: String) {
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
                hashtag: "video",
                signedBy: account
            )
            
            getRelayPool().publishEvent(event)
        } catch {
            print("Failed to publish message: \(error.localizedDescription)")
        }
    }
    
    private func startListening() {
        // Listen for uploadVideo notifications globally
        NotificationCenter.default.publisher(for: .uploadVideo)
            .sink { notification in
                if let assetURL = notification.userInfo?["assetURL"] as? String, let channelId = notification.userInfo?["channelId"] as? String  {
                    self.handleUploadVideo(channelId: channelId, assetURL: assetURL)
                }
            }
            .store(in: &cancellables)
        
        // Add more listeners here if needed
    }
    
    private func handleUploadVideo(channelId: String, assetURL: String) {
        self.publishVideoEvent(channelId: channelId, kind: .video, content: assetURL)
        print("Video uploaded: \(assetURL)")
    }
}

extension Notification.Name {
    static let createdChannelForInbound = Notification.Name("createdChannelForInbound")
    static let createdChannelForOutbound = Notification.Name("createdChannelForOutbound")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
}
