//
//  ContentView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import NostrSDK
import SwiftUI

class Lobby: ObservableObject {
    @Published var guests: [String: Date] = [:]
}

class ContentViewModel: ObservableObject, RelayDelegate, LegacyDirectMessageEncrypting, EventCreating {
    @Published var isConnected: Bool = false
    @Published var fetchingStoredEvents: Bool = true
    
    @AppStorage("npub") var npub: String = ""
    @AppStorage("nsec") var nsec: String = ""
    
    var relayPool = try! RelayPool(relayURLs: [
        URL(string: Constants.RELAY_URL_PRIMAL)!
    ])
        
    private var subscriptionId: String?
    private var eventsCancellable: AnyCancellable?
    
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
            updateSubscription()
        }
    }
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
            self.fetchingStoredEvents = false
        }
    }
    
    private var currentFilter: Filter {
        print(npub)
        let publicKey = PublicKey(npub: npub)!.hex
        return Filter(kinds: [4], tags: ["p" : [publicKey]])!
    }
    
    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = relayPool.subscribe(with: currentFilter)
                
        relayPool.delegate = self
        
        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                let key = PublicKey(hex: event.pubkey)!.npub
                self.room.guests[key] = event.createdDate
            }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    @EnvironmentObject var relayPool: RelayPool

    @StateObject private var store = HostStore()

    @State private var selection: Tab = .wallet
    
    @State private var subscriptionId: String?
    
    @State private var eventsCancellable: AnyCancellable?

    enum Tab {
        case lobby
        case spots
        case wallet
        case debug
        case settings
    }
    
    var body: some View {
        TabView(selection: $selection) {
            Skatepark()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
                .tag(Tab.lobby)
                .environmentObject(viewModel.room)

            Skate()
                .tabItem {
                    Label("Skate", systemImage: "map")
                }
                .tag(Tab.spots)
            
//            NostrDebugFeed()
//                .tabItem {
//                    Label("Debug", systemImage: "ellipsis.message")
//                }
//                .tag(Tab.debug)
            
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
                try await store.load()

                if (store.host.npub != "" || store.host.nsec != "") {
                    viewModel.npub = store.host.npub
                    viewModel.nsec = store.host.nsec
                } else {
                    let keypair = Keypair()!
                    
                    let host = Host(
                        publicKey: keypair.publicKey.hex,
                        privateKey: keypair.privateKey.hex,
                        npub: keypair.publicKey.npub,
                        nsec: keypair.privateKey.nsec
                    )
                    
                    viewModel.npub = host.npub
                    viewModel.nsec = host.nsec
                                        
                    try await store.save(host: host)
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
    ContentView().environment(ModelData())
}
