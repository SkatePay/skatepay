//
//  ContentView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import ConnectFramework
import Combine
import CoreLocation
import NostrSDK
import SwiftData
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
    @Published var channels: [String: Channel] = [:]
    @Published var leads: [String: Lead] = [:]
    @Published var events: [ActivityEvent] = []
}

struct ActivityEvent {
    var id: String
    var npub: String
}

class ContentViewModel: ObservableObject, RelayDelegate, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.modelContext) private var context
    
    @Published var isConnected: Bool = false
    @Published var fetchingStoredEvents: Bool = true
    
    let keychainForNostr = NostrKeychainStorage()
    
    var relayPool = try! RelayPool(relayURLs: [
        URL(string: Constants.RELAY_URL_PRIMAL)!
    ])
    
    private var subscriptionForChannels, subscriptionForDirectMessages: String?
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
            
            // Bootstrap Public
            let eventId = AppData().landmarks[0].eventId
            self.room.leads[eventId] = Lead(name: "Public Chat", icon: "💬", coordinate: AppData().landmarks[0].locationCoordinate, eventId: eventId, event: nil, channel: nil)
        }
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            print(subscriptionId, self.subscriptionForChannels!)
            
            if (subscriptionId == self.subscriptionForDirectMessages) {
                self.fetchingStoredEvents = false
            }
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
        if let subscriptionForChannels {
            relayPool.closeSubscription(with: subscriptionForChannels)
        }
        
        if let subscriptionForDirectMessages {
            relayPool.closeSubscription(with: subscriptionForDirectMessages)
        }
        
        if let unwrappedFilter = filterForGroupMessages {
            subscriptionForChannels = relayPool.subscribe(with: unwrappedFilter)
        }
        
        if let unwrappedFilter = filterForDirectMessages {
            subscriptionForDirectMessages = relayPool.subscribe(with: unwrappedFilter)
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
                if (event.kind == EventKind.channelCreation) {
                    if let channel = parseChannel(from: event.content) {
                        self.room.channels[event.id] = channel
                        
                        if var lead = self.room.leads[event.id] {
                            // Bootstrapped value
                            lead.channel = channel
                            lead.event = event
                            self.room.leads[event.id] = lead
                        } else {
                            // New value check with bookmarks for location
                            self.room.leads[event.id] = Lead(
                                    name: channel.name,
                                    icon: "🛹",
                                    coordinate: CLLocationCoordinate2D(
                                        latitude: 33.98698741635913,
                                        longitude: -118.47553109622498),
                                    eventId: event.id,
                                    event: event,
                                    channel: channel
                                )
                        }
                    }
                }
                
                if (event.kind == EventKind.channelMetadata) {
                }
                
                if (event.kind == EventKind.legacyEncryptedDirectMessage) {
                    let publicKey = PublicKey(hex: event.pubkey)
                    
                    if let npub = publicKey?.npub {
                        self.room.events.append(ActivityEvent(id: event.id, npub: npub ))
                    }
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
                .environmentObject(viewModel.room)
                .tag(Tab.lobby)

            
            SkateView()
                .tabItem {
                    Label("Skate", systemImage: "map")
                }
                .environmentObject(viewModel.room)
                .tag(Tab.map)
            
            if (hasWallet()) {
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
            } else {
                SettingsView(host: $store.host)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(Tab.settings)
            }
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
