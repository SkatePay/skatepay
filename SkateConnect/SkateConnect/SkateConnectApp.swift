//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import CoreLocation
import NostrSDK
import SwiftUI
import SwiftData

class NetworkConnections: ObservableObject {
    static let shared = NetworkConnections()
    
    @Published var relayPool = try! RelayPool(relayURLs: [
        URL(string: Constants.RELAY_URL_PRIMAL)!
    ])
    
    func reconnectRelaysIfNeeded() {
        for (_, relay) in relayPool.relays.enumerated() {
            if relay.state != .connected {
                print("Attempting to reconnect to relay: \(relay.url)")
                relay.connect()
            }
        }
    }
}

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var path = NavigationPath()
    @Published var landmark: Landmark?
    @Published var coordinates: CLLocationCoordinate2D?
    
    @Published var isShowingEULA = false
    @Published var isShowingDirectory = false
    @Published var isShowingChannelFeed = false
    @Published var isShowingSearch = false
    @Published var isShowingCreateChannel = false
    @Published var isShowingMarkerOptions = false
    
    @Published var isShowingUserDetail = false
    
    func dismissToContentView() {
        path = NavigationPath()
        NotificationCenter.default.post(name: .goToLandmark, object: nil)
        isShowingDirectory = false
    }
    
    func dismissToSkateView() {
        isShowingMarkerOptions = false
        isShowingCreateChannel = false
    }
    
    func recoverFromSearch() {
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
        isShowingSearch = false
    }
    
    func joinChat(channelId: String) {
        NotificationCenter.default.post(
            name: .joinChat,
            object: self,
            userInfo: ["channelId": channelId]
        )
        isShowingSearch = false
    }
}

@main
struct SkateConnectApp: App {
    @State private var modelData = AppData()
    
    @AppStorage("hasAcknowledgedEULA") private var hasAcknowledgedEULA = false
    
    var body: some Scene {
        WindowGroup {
            if hasAcknowledgedEULA {
                ContentView()
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self])
                    .environment(modelData)
            } else {
                EULAView(hasAcknowledgedEULA: $hasAcknowledgedEULA)
                
            }
        }
    }
}
