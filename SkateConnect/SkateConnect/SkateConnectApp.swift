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

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @ObservedObject var lobby = Lobby.shared
    
    private let modelContainer: ModelContainer
    
    init(inMemory: Bool = false) {
        do {
            self.modelContainer = try ModelContainer(for: Friend.self, Foe.self, Spot.self)
        } catch {
            print("Failed to initialize ModelContainer: \(error)")
            // Handle the error, e.g., crash the app with a fatal error or proceed with a fallback
            fatalError("Failed to initialize ModelContainer")
        }
    }
    
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    func insertSpot(_ spot: Spot) {
        modelContext.insert(spot)
        do {
            try modelContext.save()
            
            let spots = fetchSortedSpots()
            
            lobby.setupLeads(spots: spots)
        } catch {
            print("Failed saving: \(error)")
        }
    }
    
    func fetchSortedSpots() -> [Spot] {
        do {
            let fetchDescriptor = FetchDescriptor<Spot>(
                sortBy: [SortDescriptor(\.name, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Spots: \(error)")
            return []
        }
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
