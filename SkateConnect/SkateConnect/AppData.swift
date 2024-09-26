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
            if findSpot(lead.channelId) != nil {
                // Handle existing spot if needed
                print("Spot already exists for eventId: \(lead.channelId)")
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
                    channelId: lead.channelId
                )
                
                self.insertSpot(spot)
                print("New spot inserted for eventId: \(lead.channelId)")
                
                self.lobby.leads[spot.channelId] = lead
            }
        } else {
            print("No lead provided, cannot save spot.")
        }
        
    }
}

class ApiService: ObservableObject {
    @Published var leads: [Lead] = []
    @Published var isLoading = false
    @Published var error: Error?

    func fetchLeads() {
        guard let url = URL(string: "\(Constants.API_URL_SKATEPARK)/leads") else {
            self.error = URLError(.badURL)
            self.isLoading = false
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [Lead].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.error = error
                case .finished:
                    break
                }
            } receiveValue: { [weak self] leads in
                self?.leads = leads
                self?.error = nil // Clear any previous errors if successful
            }
            .store(in: &subscriptions)
    }

    func debugOutput() -> String {
        if let error = error {
            return error.localizedDescription
        }
        return isLoading ? "Loading..." : "Finished loading data."
    }

    private var subscriptions = Set<AnyCancellable>()
}
