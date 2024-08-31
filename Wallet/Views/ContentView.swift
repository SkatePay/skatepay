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
        }
    }
}

#Preview {
    ContentView().environment(ModelData())
}
