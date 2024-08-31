//
//  ContentView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct ContentView: View {
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
                .tag(Tab.spots)
            
            SettingsHome()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.spots)
        }
    }
}

#Preview {
    ContentView().environment(ModelData())
}
