//
//  AppData.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import ConnectFramework
import Foundation
import SwiftUI
import SwiftData

@Observable
class AppData {
    var landmarks: [Landmark] = load("landmarkData.json")
    var users: [User] = load("userData.json")
    var profile = Profile.default
    
    func getSupport() -> User {
        return AppData().users[0]
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
    
    // MARK: Spots
    func findSpotForChannelId(_ channelId: String) -> Spot? {
        return fetchSortedSpots().first { $0.channelId == channelId }
    }
    
    func saveSpotForLead(_ lead: Lead?) {
        if let lead = lead {
            // Find the spot associated with the lead's eventId
            if let spot = findSpotForChannelId(lead.channelId) {
                // Handle existing spot if needed
                print("Spot already exists for eventId: \(spot.channelId)")
            } else {
                let note = lead.icon
                let spot = Spot(
                    name: lead.name,
                    address: "",
                    state: "",
                    note: note,
                    latitude: lead.coordinate.latitude,
                    longitude: lead.coordinate.longitude,
                    channelId: lead.channelId
                )
                
                self.insertSpot(spot)
                print("New spot inserted for eventId: \(lead.channelId)")
            }
            
            self.lobby.upsertIntoLeads(lead)
        } else {
            print("No lead provided, cannot save spot.")
        }
        
    }
    
    func createSpots(leads: [Lead]) {
        for lead in leads {
            saveSpotForLead(lead)
        }
    }
    
    // MARK: Friends
    func fetchFriends() -> [Friend] {
        do {
            let fetchDescriptor = FetchDescriptor<Friend>(
                sortBy: [SortDescriptor(\.name, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Spots: \(error)")
            return []
        }
    }
    
    func findFriend(_ npub: String) -> Friend? {
        return fetchFriends().first(where: { $0.npub == npub })
    }
    
}
