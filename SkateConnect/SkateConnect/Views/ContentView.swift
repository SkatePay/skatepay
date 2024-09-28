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
            channelId: eventId,
            event: nil,
            channel: nil
        )
        
        for spot in spots.filter({ $0.note == "invite" }) {
            let lead = Lead(
                name: spot.name,
                icon: "🏆",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                channelId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.leads[lead.channelId] = lead
        }
        
        for spot in spots.filter({ $0.note == "channel"}) {
            let lead = Lead(
                name: spot.name,
                icon: "📡",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                channelId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.leads[lead.channelId] = lead
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
    
    @ObservedObject var networkConnections = Network.shared
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject var dataManager = DataManager.shared
    
    private var subscriptionForChannels, subscriptionForDirectMessages: String?
    private var eventsCancellableForGroup, eventsCancellableForDirect: AnyCancellable?
        
    var mark: Mark?
        
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if (state == .connected) {
//            self.updateSubscriptions()
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
        return networkConnections.getRelayPool()
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
        let filter = Filter(kinds: [
            EventKind.legacyEncryptedDirectMessage.rawValue, 
            EventKind.channelCreation.rawValue
        ], tags: ["p" : [account.publicKey.hex]])
        return filter
    }
    
    private func handleEvent(_ event: NostrEvent) {
        if (event.kind == EventKind.channelCreation) {
            if let channel = parseChannel(from: event.content) {
                self.lobby.channels[event.id] = channel
                
                if var lead = self.lobby.leads[event.id] {
                    // Bootstrapped value
                    lead.channel = channel
                    lead.event = event
                    self.lobby.leads[event.id] = lead
                } else {
                    if self.dataManager.findSpot(event.id) != nil {
                        self.lobby.leads[event.id] = createLead(from: event)
                    } else {
                        if let mark = self.mark {
                            // Create new spot record
                            
                            self.observedSpot = ObservedSpot()
                            
                            let spot = Spot(
                                name: channel.name,
                                address: "",
                                state: "",
                                note: "channel",
                                latitude: mark.coordinate.latitude,
                                longitude: mark.coordinate.longitude,
                                channelId: event.id
                            )
                            
                            self.observedSpot.spot = spot
                            
                            let lead = createLead(from: event)
                            self.dataManager.saveSpotForLead(lead)
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
                self.lobby.events.append(ActivityEvent(id: event.id, npub: npub ))
            }
        }
    }
    
    func updateSubscriptions() {
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
            .sink(receiveValue: handleEvent)
    }
}

struct ContentView: View {
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var networkConnections = Network.shared
        
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var store = HostStore()
        
    let keychainForNostr = NostrKeychainStorage()
    
    var body: some View {
        TabView(selection: $navigation.tab) {
            LobbyView()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
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
        }
        .onAppear {
//            self.viewModel.updateSubscriptions()
//            Network.shared.up
        }
        .environmentObject(viewModel)
        .environmentObject(store)
    }
}

#Preview {
    ContentView().environment(AppData())
}
