//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import SwiftUI

@main
struct SkateConnectApp: App {
    @State private var modelData = AppData()

    @StateObject private var apiService = API()
    @StateObject private var channelViewManager = ChannelViewManager()
    @StateObject private var dataManager = DataManager()
    @StateObject private var debugManager = DebugManager()
    @StateObject private var eulaManager = EULAManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var lobby = Lobby()
    @StateObject private var network = Network()
    @StateObject private var navigation = Navigation()
    @StateObject private var stateManager = StateManager()
    @StateObject private var walletManager = WalletManager()

    var body: some Scene {
        WindowGroup {
            if eulaManager.hasAcknowledgedEULA {
                ContentView()
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self], inMemory: false)
                    .environment(modelData)
                    .environmentObject(apiService)
                    .environmentObject(channelViewManager)
                    .environmentObject(dataManager)
                    .environmentObject(debugManager)
                    .environmentObject(eulaManager)
                    .environmentObject(locationManager)
                    .environmentObject(lobby)
                    .environmentObject(navigation)
                    .environmentObject(network)
                    .environmentObject(stateManager)
                    .environmentObject(walletManager)
                    .onAppear {
                        apiService.setDataManager(dataManager: dataManager)
                        channelViewManager.setNavigation(navigation: navigation)
                        channelViewManager.setNetwork(network: network)
                        locationManager.setNavigation(navigation: navigation)
                        dataManager.setLobby(lobby: lobby)
                        dataManager.setWalletManager(walletManager: walletManager)
                    }
            } else {
                EULAView()
                    .environmentObject(eulaManager)
                    .environmentObject(network)
            }
        }
    }
    
    // Handle the deep linking for video and channel
    func handleDeepLink(_ url: URL) {
        guard url.host == Constants.LANDING_PAGE_HOST else { return }

        let pathComponents = url.pathComponents
        
        // Handle Video Links
        if pathComponents.contains("video") {
            if let videoIndex = pathComponents.firstIndex(of: "video"),
               videoIndex + 1 < pathComponents.count {
                let videoID = pathComponents[videoIndex + 1]
                // Handle video navigation (you can implement the logic here)
                print("Deep link videoID: \(videoID)")
            }
        }
        // Handle Channel Links
        else if pathComponents.contains("channel") {
            if let channelIndex = pathComponents.firstIndex(of: "channel"),
               channelIndex + 1 < pathComponents.count {
                let channelID = pathComponents[channelIndex + 1]
                channelViewManager.openChannel(channelId: channelID)
            }
        }
    }
}
