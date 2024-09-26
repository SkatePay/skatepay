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

class NetworkConnections: ObservableObject, RelayDelegate {
    static let shared = NetworkConnections()
    
    @Published var relayPool: RelayPool?
    
    init() {
        connect()
    }
    
    func connect() {
        do {
            self.relayPool = try RelayPool(relayURLs: [
                URL(string: Constants.RELAY_URL_PRIMAL)!], delegate: self)
        } catch {
            print("Error initializing RelayPool: \(error)")
        }
    }
    
    func getRelayPool() -> RelayPool {
        self.reconnectRelaysIfNeeded()
        return relayPool!
    }
    
    func reconnectRelaysIfNeeded() {
        guard let relays = relayPool?.relays else {
            return
        }
        
        for (_, relay) in relays.enumerated() {
            switch relay.state {
                case .notConnected:
                    print("Attempting to reconnect to relay: \(relay.url)")
                case .connecting:
                    print("Relay is currently connecting. Please wait.")
                case .connected:
                    continue
                case .error(let error):
                    print("An error occurred with the relay: \(error.localizedDescription)")

                    if error.localizedDescription == "The operation couldn’t be completed. Socket is not connected" ||
                        error.localizedDescription == "The Internet connection appears to be offline." {
                        self.connect()
                    }
            }
        }
    }
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
    }
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
        }
    }
}

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var path = NavigationPath()
    @Published var tab: Tab = .map
    
    @Published var landmark: Landmark?
    @Published var coordinate: CLLocationCoordinate2D?
    
    @Published var isShowingEULA = false
    @Published var isShowingDirectory = false
    @Published var isShowingChannelFeed = false
    @Published var isShowingSearch = false
    @Published var isShowingCreateChannel = false
    @Published var isShowingMarkerOptions = false
    
    @Published var isShowingUserDetail = false
    
    @Published var isShowingBarcodeScanner = false
    
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
    
    func goToCoordinate() {
        path = NavigationPath()
        self.tab = .map
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
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
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self], inMemory: false)
                    .environment(modelData)
            } else {
                EULAView(hasAcknowledgedEULA: $hasAcknowledgedEULA)
                
            }
        }
    }
}
