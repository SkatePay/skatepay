//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import os
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
    @StateObject private var navigation = Navigation()
    @StateObject private var stateManager = StateManager()
    @StateObject private var uploadManager = UploadManager()
    @StateObject private var videoDownloader = VideoDownloader()
    @StateObject private var walletManager = WalletManager()
    
    @StateObject private var network: Network = Network()

    let log = OSLog(subsystem: "SkateConnect", category: "DeepLinking")
    
    var body: some Scene {
        WindowGroup {
            if eulaManager.hasAcknowledgedEULA {
                ContentView()
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        guard let url = activity.webpageURL else {
                            os_log("🛑 can't get webpageURL", log: log, type: .info)
                            return
                        }
                        
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
                    .environmentObject(uploadManager)
                    .environmentObject(videoDownloader)
                    .environmentObject(walletManager)
                    .onAppear {
                        apiService.setDataManager(dataManager: dataManager)
                        channelViewManager.setNavigation(navigation: navigation)
                        channelViewManager.setNetwork(network: network)
                        locationManager.setNavigation(navigation: navigation)
                        dataManager.setLobby(lobby: lobby)
                        dataManager.setWalletManager(walletManager: walletManager)
                        uploadManager.setNavigation(navigation: navigation)
                    }
            } else {
                EULAView()
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        guard let url = activity.webpageURL else {
                            os_log("🛑 can't get webpageURL", log: log, type: .info)
                            return
                        }
                        
                        handleDeepLink(url)
                     }
                    .environmentObject(eulaManager)
                    .onAppear {
                        channelViewManager.setNavigation(navigation: navigation)
                        channelViewManager.setNetwork(network: network)
                    }
            }
        }
    }
    
    // Handle the deep linking for video and channel
    func handleDeepLink(_ url: URL) {
        os_log("🔗 Deep link received: %@", log: log, type: .info, url.absoluteString)
        
        guard url.host == Constants.LANDING_PAGE_HOST else { return }

        let pathComponents = url.pathComponents
        
        // Handle Video Links
        if pathComponents.contains("video") {
            if let videoIndex = pathComponents.firstIndex(of: "video"),
               videoIndex + 1 < pathComponents.count {
                let videoId = pathComponents[videoIndex + 1]
                os_log("⏳ processing videoId %@", log: log, type: .info, videoId)
            }
        }
        
        // Handle Channel Links
        else if pathComponents.contains("channel") {
            if let channelIndex = pathComponents.firstIndex(of: "channel"),
               channelIndex + 1 < pathComponents.count {
                let channelId = pathComponents[channelIndex + 1]
                channelViewManager.openChannel(channelId: channelId, deeplink: true)
            }
        }
    
        // Handle DM Links
        else if pathComponents.contains("user") {
            if let channelIndex = pathComponents.firstIndex(of: "user"),
               channelIndex + 1 < pathComponents.count {
                let npub = pathComponents[channelIndex + 1]
                os_log("⏳ processing npub %@", log: log, type: .info, npub)
                navigation.path.append(NavigationPathType.userDetail(npub: npub))
            }
        }
    }
}
