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
}

func convertNoteToColor(_ note: String) -> Color {
    let color: Color
    switch note {
    case "invite":
        color = Color(uiColor: UIColor.systemPink)
    case "public":
        color = Color(uiColor: UIColor.systemPurple)
    case "private":
        color = .orange
    default:
        color = Color(uiColor: UIColor.systemBlue)
    }
    return color;
}

func createLead(from event: NostrEvent, note: String = "") -> Lead? {
    var lead: Lead?
    
    if let channel = parseChannel(from: event) {
        let about = channel.about
        
        do {
            let decoder = JSONDecoder()
            let decodedStructure = try decoder.decode(AboutStructure.self, from: about.data(using: .utf8)!)
            
            var icon = "📺"
            if let note = decodedStructure.note {
                icon = note
            }
            
            lead = Lead(
                name: channel.name,
                icon: icon,
                coordinate: decodedStructure.location,
                channelId: event.id,
                event: event,
                channel: channel,
                color: convertNoteToColor(note)
            )
        } catch {
            print("Error decoding: \(error)")
        }
    }
    return lead
}

struct ActivityEvent {
    var id: String
    var npub: String
}
