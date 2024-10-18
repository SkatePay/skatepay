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
    
    @ObservedObject var navigation = Navigation.shared
    
    // Instantiate the global listener when the app starts
    init() {
        let _ = GlobalListener.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if (navigation.hasAcknowledgedEULA) {
                ContentView()
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self], inMemory: false)
                    .environment(modelData)
            } else {
                EULAView()
            }
        }
    }
    
    func handleDeepLink(_ url: URL) {
        guard url.host == Constants.LANDING_PAGE_HOST else { return }

        let pathComponents = url.pathComponents

        // Handle Video Links
        if pathComponents.contains("video") {
            if let videoIndex = pathComponents.firstIndex(of: "video"),
               videoIndex + 1 < pathComponents.count {
                let videoID = pathComponents[videoIndex + 1]
//                navigateToVideoView(with: videoID)
                print(videoID)
            }
        }
        // Handle Channel Links
        else if pathComponents.contains("channel") {
            if let channelIndex = pathComponents.firstIndex(of: "channel"),
               channelIndex + 1 < pathComponents.count {
                let channelID = pathComponents[channelIndex + 1]
                navigation.viewChannel(channelId: channelID)
            }
        }
    }
}
