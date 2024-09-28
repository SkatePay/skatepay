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



class Network: ObservableObject, RelayDelegate {
    static let shared = Network()
    
    @Published var relayPool: RelayPool?
    
    private var activeSubscriptions: [String] = []
    private var eventsCancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()

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
    
    // MARK: - RelayDelegate
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        switch state {
            case .connected:
                updateSubscriptions(filterForChannels: filterForChannels, filterForDirectMessages: filterForDirectMessages)
        case .notConnected:
            return
        case .connecting:
            return
        case .error(_):
            return
        }
    }
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        print(event)
    }
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
            print("A")
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
        let filter = Filter(kinds: [EventKind.legacyEncryptedDirectMessage.rawValue, EventKind.channelCreation.rawValue], tags: ["p" : [account.publicKey.hex]])
        return filter
    }
    
    // MARK: - Subscriptions
    func updateSubscriptions(filterForChannels: Filter?, filterForDirectMessages: Filter?) {
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
    func handleEvent(_ event: NostrEvent) {
        switch event.kind {
            case .channelCreation:
                handleChannelCreation(event)
            default:
                print("Unhandled event kind: \(event.kind)")
        }
    }
    
    // Process channel creation event
    private func handleChannelCreation(_ event: NostrEvent) {
        NotificationCenter.default.post(name: .newChannelCreated, object: event)
    }
}

extension Notification.Name {
    static let newChannelCreated = Notification.Name("newChannelCreated")
}
