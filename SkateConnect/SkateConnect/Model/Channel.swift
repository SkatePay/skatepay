//
//  Channel.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/27/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI
import SwiftData
import CoreLocation

struct Channel: Codable {
    var name: String
    var about: String
    var picture: String
    var relays: [String]
    var creationEvent: NostrEvent?
    var metadataEvent: NostrEvent?

    var aboutDecoded: AboutStructure? {
        guard let data = about.data(using: .utf8) else { return nil }
        
        do {
            let decodedAbout = try JSONDecoder().decode(AboutStructure.self, from: data)
            return decodedAbout
        } catch {
            print("Failed to decode 'about': \(error)")
            return nil
        }
    }
}

func parseChannel(from event: NostrEvent) -> Channel? {
    guard let data = event.content.data(using: .utf8) else {
        print("Failed to convert string to data")
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        var channel = try decoder.decode(Channel.self, from: data)
        channel.creationEvent = event
        return channel
    } catch {
        print("Error decoding JSON: \(error)")
        return nil
    }
}

struct AboutStructure: Codable {
    let description: String
    let location: CLLocationCoordinate2D
    let note: String?
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try values.decode(Double.self, forKey: .latitude)
        let longitude = try values.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

enum ChannelEmoji: String, CaseIterable, Identifiable {
    case broadcast = "📡"
    case content = "🎥"
    case game = "🏆"
    case job = "🧹"
    case skate = "🛹"
    case repair = "🛠️"
    case note = "📝"
    case idea = "💡"
    case camp = "⛺️"
    case bank = "🏦"
    
    var id: String { rawValue }
}
