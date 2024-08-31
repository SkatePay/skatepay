//
//  ContentView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = HostStore()

    @State private var selection: Tab = .lobby

    enum Tab {
        case lobby
        case spots
        case wallet
        case chat
        case settings
    }
    
    var body: some View {
        TabView(selection: $selection) {
            LobbyHome()
                .tabItem {
                    Label("Lobby", systemImage: "star")
                }
                .tag(Tab.lobby)


            LandmarkList()
                .tabItem {
                    Label("Spots", systemImage: "list.bullet")
                }
                .tag(Tab.spots)
            
            WalletHome()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard.and.123")
                }
                .tag(Tab.wallet)
            
            SettingsHome(host: $store.host) {
                    Task {
                        do {
                            try await store.save(host: store.host)
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
                .task {
                    do {
                        try await store.load()
                    } catch {
//                        fatalError(error.localizedDescription)
                    }
                }
        }
    }
}

#Preview {
    ContentView().environment(ModelData())
}
