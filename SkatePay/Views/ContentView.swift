//
//  ContentView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import NostrSDK
import SwiftUI

enum Tab {
    case lobby
    case spots
    case wallet
    case debug
    case settings
}

class Lobby: ObservableObject {
    @Published var guests: [String: Date] = [:]
}

class ContentViewModel: ObservableObject, RelayDelegate, LegacyDirectMessageEncrypting, EventCreating {
    @Published var isConnected: Bool = false
    @Published var fetchingStoredEvents: Bool = true
    
    let keychainForSolana = NostrKeychainStorage()
    
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
        print(event)
    }
    
//    func relay(_ relay: Relay, didReceive response: RelayResponse) {
//        DispatchQueue.main.async {
//            guard case .eose(_) = response else {
//                return
//            }
//            self.fetchingStoredEvents = false
//        }
//    }
    
    private var currentFilter: Filter? {
        guard let account = keychainForSolana.account else {
            print("Error: Failed to create Filter")
            return nil
        }
        
        let filter = Filter(kinds: [4], tags: ["p" : [account.publicKey.hex]])
        
        return filter
    }
    
    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        if let unwrappedFilter = currentFilter {
            subscriptionId = relayPool.subscribe(with: unwrappedFilter)
        } else {
            // Handle the case where currentFilter is nil
            print("currentFilter is nil, unable to subscribe")
        }
        
        relayPool.delegate = self
        
        eventsCancellable = relayPool.events
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
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    @StateObject private var store = HostStore()

    @State private var selection: Tab = .wallet
    
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
                .tag(Tab.spots)
            
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
                    
                    let host = Host(
                        publicKey: keypair.publicKey.hex,
                        privateKey: keypair.privateKey.hex,
                        npub: keypair.publicKey.npub,
                        nsec: keypair.privateKey.nsec
                    )
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
