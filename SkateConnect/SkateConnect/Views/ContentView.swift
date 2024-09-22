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
    static let shared = Lobby()
    
    @Published var channels: [String: Channel] = [:]
    @Published var leads: [String: Lead] = [:]
    @Published var events: [ActivityEvent] = []
    
    func clear() {
        leads = [:]
        channels = [:]
        events = []
    }
    
    func setupLeads(spots: [Spot]) {
        let eventId = AppData().landmarks[0].eventId
        self.leads[eventId] = Lead(
            name: "Public Chat",
            icon: "💬",
            coordinate: AppData().landmarks[0].locationCoordinate,
            eventId: eventId,
            event: nil,
            channel: nil
        )
        
        for spot in spots.filter({ $0.note == "invite" }) {
            let lead = Lead(
                name: spot.name,
                icon: "🏆",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                eventId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.leads[lead.eventId] = lead
        }
        
        for spot in spots.filter({ $0.note == "channel"}) {
            let lead = Lead(
                name: spot.name,
                icon: "🛹",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                eventId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.leads[lead.eventId] = lead
        }
    }
}

struct ActivityEvent {
    var id: String
    var npub: String
}

class ObservedSpot: ObservableObject {
    var spot: Spot?
}

class ContentViewModel: ObservableObject, RelayDelegate, LegacyDirectMessageEncrypting, EventCreating {
    @Published var fetchingStoredEvents: Bool = true
    @Published var observedSpot: ObservedSpot = ObservedSpot()
    
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var networkConnections = NetworkConnections.shared
    
    private var subscriptionForChannels, subscriptionForDirectMessages: String?
    private var eventsCancellableForGroup, eventsCancellableForDirect: AnyCancellable?
    
    @Published var room: Lobby = Lobby()
    
    var mark: Mark?
    
    var spots: [Spot] = []
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if (state == .connected) {
            self.updateSubscriptions()
        }
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            
            if (subscriptionId == self.subscriptionForDirectMessages) {
                self.fetchingStoredEvents = false
            }
        }
    }
    
    private var relayPool: RelayPool {
        networkConnections.reconnectRelaysIfNeeded()
        return networkConnections.relayPool
    }
    
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
    
    func updateSubscriptions() {
        networkConnections.reconnectRelaysIfNeeded()
        
        if let subscriptionForChannels {
            relayPool.closeSubscription(with: subscriptionForChannels)
        }
        
        if let subscriptionForDirectMessages {
            relayPool.closeSubscription(with: subscriptionForDirectMessages)
        }
        
        if let unwrappedFilter = filterForChannels {
            subscriptionForChannels = relayPool.subscribe(with: unwrappedFilter)
        }
        
        if let unwrappedFilter = filterForDirectMessages {
            subscriptionForDirectMessages = relayPool.subscribe(with: unwrappedFilter)
        }
        
        relayPool.delegate = self
        
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
                            if let spot = self.findSpotByChannelId(event.id) {
                                self.room.leads[event.id] = Lead(
                                    name: channel.name,
                                    icon: "🛹",
                                    coordinate: CLLocationCoordinate2D(
                                        latitude: spot.locationCoordinate.latitude,
                                        longitude: spot.locationCoordinate.longitude),
                                    eventId: event.id,
                                    event: event,
                                    channel: channel
                                )
                            } else {
                                if let mark = self.mark {
                                    let spot = ObservedSpot()
                                    spot.spot = Spot(
                                        name: channel.name,
                                        address: "",
                                        state: "",
                                        note: "channel",
                                        latitude: mark.coordinate.latitude,
                                        longitude: mark.coordinate.longitude,
                                        channelId:
                                            event.id
                                    )
                                    self.observedSpot = spot
                                    
                                } else {
                                    print("unknown channel location")
                                }
                                
                                self.mark = nil
                            }
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
    
    func findSpotByChannelId(_ channelId: String) -> Spot? {
        return spots.first { $0.channelId == channelId }
    }
}

struct ContentView: View {
    @ObservedObject var networkConnections = NetworkConnections.shared
    
    @Query(sort: \Spot.channelId) private var spots: [Spot]
    
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
                .environmentObject(viewModel)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
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
                    .environmentObject(viewModel.room)
                    .environmentObject(viewModel)
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
            
            viewModel.spots = spots
        }
        .onAppear {
            self.viewModel.updateSubscriptions()
        }
        .environmentObject(viewModel)
        .environmentObject(store)
    }
}

#Preview {
    ContentView().environment(AppData())
}
