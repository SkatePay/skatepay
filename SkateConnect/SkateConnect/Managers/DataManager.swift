//
//  DataManager.swift
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
    @Published private var lobby: Lobby?
    
    private let modelContainer: ModelContainer
    
    init(inMemory: Bool = false) {
        do {
            self.modelContainer = try ModelContainer(for: Friend.self, Foe.self, Spot.self)
        } catch {
            print("Failed to initialize ModelContainer: \(error)")
            fatalError("Failed to initialize ModelContainer")
        }
    }
    
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    func setLobby(lobby: Lobby) {
        self.lobby = lobby
    }
    
    func insertSpot(_ spot: Spot) {
        modelContext.insert(spot)
        do {
            try modelContext.save()
            
            let spots = fetchSortedSpots()
            
            lobby?.setupLeads(spots: spots)
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
    
    func saveSpotForLead(_ lead: Lead, note: String = "") {
        var bufferedLead = lead
        
        if let spot = findSpotForChannelId(lead.channelId) {
            print("Spot already exists for eventId: \(spot.channelId) \(spot.note)")
            
            let note = spot.note.split(separator: ":").last.map(String.init) ?? ""
            bufferedLead.color = convertNoteToColor(note)
        } else {
            let spot = Spot(
                name: lead.name,
                address: "",
                state: "",
                icon: lead.icon,
                note: lead.icon + ":" + note,
                latitude: lead.coordinate.latitude,
                longitude: lead.coordinate.longitude,
                channelId: lead.channelId
            )
            
            self.insertSpot(spot)
            bufferedLead.color = convertNoteToColor(note)
            print("New spot inserted for eventId: \(lead.channelId)")
        }
        
        self.lobby?.upsertIntoLeads(bufferedLead)
    }
    
    func removeSpotForChannelId(_ channelId: String) {
        do {
            if let spotToRemove = findSpotForChannelId(channelId) {
                modelContext.delete(spotToRemove)
                try modelContext.save()

                // Re-fetch sorted spots and update the lobby leads
                let spots = fetchSortedSpots()
                            
                self.lobby?.setupLeads(spots: spots)
                self.lobby?.removeLeadByChannelId(channelId)
                
                print("Spot with channelId \(channelId) removed.")
            } else {
                print("Spot with channelId \(channelId) not found.")
            }
        } catch {
            print("Failed to remove spot: \(error)")
        }
    }
    
    func createPublicSpots(leads: [Lead]) {
        for lead in leads {
            saveSpotForLead(lead, note: "public")
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
            print("Failed to fetch and sort Friends: \(error)")
            return []
        }
    }
    
    func findFriend(_ npub: String) -> Friend? {
        return fetchFriends().first(where: { $0.npub == npub })
    }
    
    // MARK: Foes
    func fetchFoes() -> [Foe] {
        do {
            let fetchDescriptor = FetchDescriptor<Foe>(
                sortBy: [SortDescriptor(\.npub, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Foes: \(error)")
            return []
        }
    }
    
    func findFoes(_ npub: String) -> Foe? {
        return fetchFoes().first(where: { $0.npub == npub })
    }
}
