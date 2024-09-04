//
//  ContentView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import NostrSDK
import SwiftUI

class PoolDelegate: ObservableObject, RelayDelegate {
    @Published var fetchingStoredEvents = true
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
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
}

class Room: ObservableObject {
    @Published var guests: [String: Date] = [:]
}

struct ContentView: View {
    @EnvironmentObject var relayPool: RelayPool

    @StateObject var poolDelegate = PoolDelegate()

    @StateObject private var store = HostStore()

    @State private var selection: Tab = .lobby

    @AppStorage("npub") var npub: String = ""
    @AppStorage("nsec") var nsec: String = ""
    
    @State private var subscriptionId: String?
    
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var room: Room = Room()

    enum Tab {
        case lobby
        case spots
        case wallet
        case debug
        case settings
    }
    
    var body: some View {
        TabView(selection: $selection) {
            LobbyHome()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
                .tag(Tab.lobby)
                .environmentObject(room)


            LandmarkList()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(Tab.spots)
            
//            NostrDebugFeed()
//                .tabItem {
//                    Label("Debug", systemImage: "ellipsis.message")
//                }
//                .tag(Tab.debug)
            
            WalletHome(host: $store.host) {
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
                                
                npub = store.host.npub
                nsec = store.host.nsec
                
                updateSubscription()
            } catch {
//                        fatalError(error.localizedDescription)
            }
        }
        .environmentObject(store)
    }
        
    private var currentFilter: Filter {
        let publicKey = store.host.publicKey
        
        return Filter(kinds: [4], tags: ["p" : [publicKey]])!
    }
    
    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = relayPool.subscribe(with: currentFilter)
        relayPool.delegate = self.poolDelegate
                
        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                let key = PublicKey(hex: event.pubkey)!.npub
                room.guests[key] = event.createdDate
            }
    }
}

#Preview {
    ContentView().environment(ModelData())
}
