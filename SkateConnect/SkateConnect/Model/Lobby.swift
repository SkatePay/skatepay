//
//  Lobby.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/28/24.
//

import CoreLocation
import Foundation
import NostrSDK

class Lobby: ObservableObject {
    static let shared = Lobby()
    
    @Published var leads: [Lead] = []
    @Published var events: [ActivityEvent] = []
    @Published var dms: Set<NostrEvent> = []
    
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
        for spot in spots {
            if let channelType = ChannelType(rawValue: spot.note) {
                let lead = Lead(
                    name: spot.name,
                    icon: channelType.rawValue,
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    channelId: spot.channelId,
                    event: nil,
                    channel: nil
                )
                self.upsertIntoLeads(lead)
            }
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
