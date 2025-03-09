//
//  Lobby.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/28/24.
//

import CoreLocation
import Foundation
import NostrSDK
import SwiftUI

class Lobby: ObservableObject {
    @Published var leads: [Lead] = []
    @Published var events: [ActivityEvent] = []
    @Published var dms: Set<NostrEvent> = []
    @Published var readMessages: [String: Int64] = [:] // Tracks last read timestamp per npub

    init() {
        loadReadMessages()
    }
    
    func markMessageAsRead(npub: String, timestamp: Int64) {
        readMessages[npub] = timestamp
        saveReadMessages()
        objectWillChange.send() // Notify UI to update
    }

    func isMessageRead(npub: String, timestamp: Int64) -> Bool {
        return readMessages[npub] ?? 0 >= timestamp
    }

    private func saveReadMessages() {
        UserDefaults.standard.setValue(readMessages, forKey: "readMessages")
    }

    private func loadReadMessages() {
        if let savedData = UserDefaults.standard.dictionary(forKey: "readMessages") as? [String: Int64] {
            readMessages = savedData
        }
    }
    
    func clear() {
        leads = []
        events = [] 
        dms = []
    }
    
    let keychainForNostr = NostrKeychainStorage()

    func findLead(byChannelId channelId: String) -> Lead? {
        return leads.first { $0.channelId == channelId }
    }
    
    func removeLeadByChannelId(_ channelId: String) {
        leads.removeAll { $0.channelId == channelId }
    }

    func upsertIntoLeads(_ element: Lead) {
        if let index = leads.firstIndex(where: { $0.channelId == element.channelId }) {
            leads[index] = element
        } else {
            leads.append(element)
        }
    }
    
    func setupLeads(spots: [Spot]) {
        for spot in spots {
            // if note invite, public, mine
            let note = spot.note.split(separator: ":").last.map(String.init) ?? ""

            if let channelType = ChannelType(rawValue: spot.icon) {
                let lead = Lead(
                    name: spot.name,
                    icon: channelType.rawValue,
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    channelId: spot.channelId,
                    event: nil,
                    channel: nil,
                    color: convertNoteToColor(note)
                )
                self.upsertIntoLeads(lead)
            }
        }
    }
    
    func incoming() -> [String] {
        let uniquePubkeys = Set(dms.map { $0.pubkey })
        return Array(uniquePubkeys)
    }
    
    func addEvent(_ event: NostrEvent) {
        if let publicKey = PublicKey(hex: event.pubkey) {
            let activityEvent = ActivityEvent(
                id: event.id,
                npub: publicKey.npub,
                createdAt: event.createdAt
            )
            events.append(activityEvent)
        }
    }
    
    func groupedEvents() -> [String: [ActivityEvent]] {
        let filteredEvents = events.filter { $0.npub != keychainForNostr.account?.publicKey.npub }
        let grouped = Dictionary(grouping: filteredEvents, by: { $0.npub })
        
        // Sort events within each group by createdAt in descending order
        let sortedGrouped = grouped.mapValues { events in
            events.sorted { $0.createdAt > $1.createdAt }
        }
        
        return sortedGrouped
    }
}

struct ActivityEvent {
    var id: String
    var npub: String
    var createdAt: Int64
}
