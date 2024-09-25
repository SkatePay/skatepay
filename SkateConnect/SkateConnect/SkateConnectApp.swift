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
            if relay.state == .notConnected {
                print("Attempting to reconnect to relay: \(relay.url)")
                relay.connect()
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

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @ObservedObject var lobby = Lobby.shared
    
    private let modelContainer: ModelContainer
    private let keychainForNostr = NostrKeychainStorage()

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
    
    func findSpot(_ eventId: String) -> Spot? {
        return fetchSortedSpots().first { $0.channelId == eventId }
    }
    
    func createSpot(lead: Lead?) {
        if let lead = lead {
            // Find the spot associated with the lead's eventId
            if findSpot(lead.eventId) != nil {
                // Handle existing spot if needed
                print("Spot already exists for eventId: \(lead.eventId)")
            } else {
                // Create a new spot if one doesn't exist
                var note = "invite"
                
                if (keychainForNostr.account?.publicKey.hex == lead.event?.pubkey) {
                    note = "channel"
                }
                
                note = lead.icon
                let spot = Spot(
                    name: lead.name,
                    address: "",
                    state: "",
                    note: note,
                    latitude: lead.coordinate.latitude,
                    longitude: lead.coordinate.longitude,
                    channelId: lead.eventId
                )
                
                self.insertSpot(spot)
                print("New spot inserted for eventId: \(lead.eventId)")
                
                self.lobby.leads[spot.channelId] = lead
            }
        } else {
            print("No lead provided, cannot save spot.")
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
