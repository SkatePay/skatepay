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
import UIKit

enum Tab {
    case lobby
    case map
    case wallet
    case debug
    case settings
}

class ContentViewModel: ObservableObject {
    @Published var fetchingStoredEvents: Bool = true
    var mark: Mark?
}

struct ContentView: View {
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var networkConnections = Network.shared
    @ObservedObject var lobby = Lobby.shared
        
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var store = HostStore()

    @State private var incomingMessagesCount = 0

    let keychainForNostr = NostrKeychainStorage()
    
    var body: some View {
        TabView(selection: $navigation.tab) {
            LobbyView()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
                .badge(incomingMessagesCount > 0 ? incomingMessagesCount : 0)
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
        .onReceive(NotificationCenter.default.publisher(for: .receivedDirectMessage)) { notification in
            if let event = notification.object as? NostrEvent {
                self.lobby.dms.insert(event)
                self.incomingMessagesCount = self.lobby.dms.count
            }
        }
        .environmentObject(viewModel)
        .environmentObject(store)
    }
}

#Preview {
    ContentView().environment(AppData())
}
