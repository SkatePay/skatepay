//
//  Spot.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation

@Model
class Spot {
    var name: String
    var address: String
    var state: String

    let icon: String
    var note: String

    let isFavorite: Bool
    let imageName: String

    var latitude: Double
    var longitude: Double
    var channelId: String

    let createdAt: Date?
    var updatedAt: Date?

    init(
        name: String,
        address: String,
        state: String,
        icon: String = "",
        note: String = "",
        isFavorite: Bool = false,
        latitude: Double = -118.475601,
        longitude: Double = 33.987164,
        channelId: String = "",
        imageName: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.address = address
        self.state = state
        self.isFavorite = isFavorite
        self.icon = icon
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.channelId = channelId
        self.imageName = imageName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var image: Image {
        Image(imageName)
    }

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Update function to refresh `updatedAt` timestamp
    func updateSpot(name: String? = nil, address: String? = nil, state: String? = nil, note: String? = nil) {
        if let name = name { self.name = name }
        if let address = address { self.address = address }
        if let state = state { self.state = state }
        if let note = note { self.note = note }
        self.updatedAt = Date() // Refresh timestamp on update
    }
}

struct CodableSpot: Codable {
    let name: String
    let address: String
    let state: String
    let icon: String
    let note: String
    let isFavorite: Bool
    let latitude: Double
    let longitude: Double
    let channelId: String
    let imageName: String
    let createdAt: Date
    let updatedAt: Date

    // Convert Spot to CodableSpot
    init(spot: Spot) {
        self.name = spot.name
        self.address = spot.address
        self.state = spot.state
        self.icon = spot.icon
        self.note = spot.note
        self.isFavorite = spot.isFavorite
        self.latitude = spot.latitude
        self.longitude = spot.longitude
        self.channelId = spot.channelId
        self.imageName = spot.imageName
        self.createdAt = spot.createdAt ?? Date()
        self.updatedAt = spot.updatedAt ?? Date()
    }

    // Custom Decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        state = try container.decode(String.self, forKey: .state)
        icon = try container.decode(String.self, forKey: .icon)
        note = try container.decode(String.self, forKey: .note)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        channelId = try container.decode(String.self, forKey: .channelId)
        imageName = try container.decode(String.self, forKey: .imageName)

        // Provide defaults if fields are missing
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
