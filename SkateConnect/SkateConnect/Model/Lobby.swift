//
//  Lobby.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/28/24.
//

import CoreLocation
import Foundation
import NostrSDK

class ObservedSpot: ObservableObject {
    var spot: Spot?
}

class Lobby: ObservableObject {
    static let shared = Lobby()
    
    @Published var leads: [Lead] = []
    @Published var events: [ActivityEvent] = []
    @Published var dms: Set<NostrEvent> = []
    
    @Published var observedSpot: ObservedSpot = ObservedSpot()

    func clear() {
        leads = []
        events = []
        dms = []
    }
    
    func findLead(byChannelId channelId: String) -> Lead? {
        return leads.first { $0.channelId == channelId }
    }
    
    func removeLead(byChannelId channelId: String) {
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
        for spot in spots.filter({ $0.note == "invite" }) {
            let lead = Lead(
                name: spot.name,
                icon: "🏆",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                channelId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.upsertIntoLeads(lead)
        }
        
        for spot in spots.filter({ $0.note == "channel"}) {
            let lead = Lead(
                name: spot.name,
                icon: "📡",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                channelId: spot.channelId,
                event: nil,
                channel: nil
            )
            self.upsertIntoLeads(lead)
        }
    }
    func incoming() -> [String] {
        let uniquePubkeys = Set(dms.map { $0.pubkey })
        return Array(uniquePubkeys)
    }
    
}

struct ActivityEvent {
    var id: String
    var npub: String
}
