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
    static let shared = Network()
    
    @Published var relayPool: RelayPool?
    
    private var activeSubscriptions: [String] = []
    private var eventsCancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()

    let keychainForNostr = NostrKeychainStorage()

    @ObservedObject var lobby = Lobby.shared

    init() {
        connect()
        
        // Observe app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // Reconnect when the app comes back to the foreground
                self?.connect()
            }
            .store(in: &cancellables)
    }
    
    func connect() {
        do {
            self.relayPool = try RelayPool(relayURLs: [
                URL(string: Constants.RELAY_URL_PRIMAL)!], delegate: self)
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
    
    func announceBirthday() {
        if (self.lobby.leads.isEmpty) { return }
            
        guard let account = keychainForNostr.account else { return }
        
        let eventId = self.lobby.leads[0].channelId
        
        do {
            if let npub = keychainForNostr.account?.publicKey.npub {
                let contentStructure = ContentStructure(content: npub, kind: .subscriber)
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(contentStructure)
                if let content  = String(data: data, encoding: .utf8) {
                    let event = try createChannelMessageEvent(
                        withContent: content,
                        eventId: eventId,
                        relayUrl: Constants.RELAY_URL_PRIMAL,
                        signedBy: account
                    )
                    getRelayPool().publishEvent(event)
                }
            }
        } catch {
            print("Failed to publish draft: \(error.localizedDescription)")
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
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
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
            .sink(receiveValue: handleEvent)
    }

    // Function to handle relay events
    private func handleEvent(_ event: NostrEvent) {
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
    
    // Process channel creation event
    private func handleChannelCreation(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .newChannelCreated, object: event)
    }
    
    // Process direct message event
    private func handleDirectMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedDirectMessage, object: event)
    }
    
    // Process channel message event
    private func handleChannelMessage(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .receivedChannelMessage, object: event)
    }
}

extension Notification.Name {
    static let newChannelCreated = Notification.Name("newChannelCreated")
    static let receivedDirectMessage = Notification.Name("receivedDirectMessage")
    static let receivedChannelMessage = Notification.Name("receivedChannelMessage")
}
