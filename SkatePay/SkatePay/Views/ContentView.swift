//
//  ContentView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import ConnectFramework
import Combine
import NostrSDK
import SwiftUI

enum Tab {
    case lobby
    case map
    case wallet
    case debug
    case settings
}

class Lobby: ObservableObject {
    @Published var guests: [String: Date] = [:]
    @Published var channels: [String] = []
    @Published var nostrEvents: [ActivityEvent] = []
}

struct ActivityEvent {
    var id: String
    var npub: String
}

class ContentViewModel: ObservableObject, RelayDelegate, LegacyDirectMessageEncrypting, EventCreating {
    @Published var isConnected: Bool = false
    @Published var fetchingStoredEvents: Bool = true
    
    let keychainForNostr = NostrKeychainStorage()
    
    var relayPool = try! RelayPool(relayURLs: [
        URL(string: Constants.RELAY_URL_SKATEPARK)!
    ])
        
    private var subscriptionForGroup, subscriptionForDirect: String?
    private var eventsCancellableForGroup, eventsCancellableForDirect: AnyCancellable?
    
    @Published var room: Lobby = Lobby()
    
    init() {
        connectRelays()
        relayPool.delegate = self
    }
    
    func connectRelays() {
        relayPool.connect()
    }
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if (state == .connected) {
            updateSubscriptions()
        }
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        let publicKey = PublicKey(hex: event.event.pubkey)
        let kind = event.event.kind
        
        let npub = publicKey!.npub
        
        DispatchQueue.main.async {
            if (kind == EventKind.legacyEncryptedDirectMessage) {
                self.room.nostrEvents.append(ActivityEvent(id: event.event.id, npub: npub))
            }
        }
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
            self.fetchingStoredEvents = false
        }
    }

    private var filterForGroupMessages: Filter? {
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
    
    private func updateSubscriptions() {
        if let subscriptionForGroup {
            relayPool.closeSubscription(with: subscriptionForGroup)
        }
        
        if let subscriptionForDirect {
            relayPool.closeSubscription(with: subscriptionForDirect)
        }
        
        if let unwrappedFilter = filterForGroupMessages {
            subscriptionForGroup = relayPool.subscribe(with: unwrappedFilter)
        }
        
        if let unwrappedFilter = filterForDirectMessages {
            subscriptionForDirect = relayPool.subscribe(with: unwrappedFilter)
        }
        
        relayPool.delegate = self
        
        eventsCancellableForDirect = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                if let publicKey = PublicKey(hex: event.pubkey) {
                    let key = publicKey.npub
                    self.room.guests[key] = event.createdDate
                } else {
                    print("Failed to create PublicKey from pubkey: \(event.pubkey)")
                }
            }
        
        eventsCancellableForGroup = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                if(event.kind == EventKind.channelCreation) {
                    self.room.channels.append(event.id)
                }
            }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    @StateObject private var store = HostStore()

    @State private var selection: Tab = .map
    
    let keychainForNostr = NostrKeychainStorage()
        
    var body: some View {
        TabView(selection: $selection) {
            LobbyView()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
                .tag(Tab.lobby)
                .environmentObject(viewModel.room)

            SkateView()
                .tabItem {
                    Label("Skate", systemImage: "map")
                }
                .tag(Tab.map)
            
            WalletView(host: $store.host) {
                    Task {
                        do {
                            try await store.save(host: store.host)
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                }
                .tabItem {
                    Label("Wallet", systemImage: "creditcard.and.123")
                }
                .tag(Tab.wallet)
        }
        .task {
            do {
                if ((keychainForNostr.account) == nil) {
                    let keypair = Keypair()!
                    try keychainForNostr.save(keypair)
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        .environmentObject(viewModel)
        .environmentObject(store)
    }
}

#Preview {
    ContentView().environment(AppData())
}
