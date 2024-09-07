//
//  Spot.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation

@Model
class Spot {
    @Attribute(.unique) let name: String
        
    let address: String
    let state: String
    
    let note: String
    
    let isFavorite: Bool
    
    let imageName: String
    
    var latitude: Double
    var longitude: Double
        
    init(name: String, address: String, state: String, note: String, isFavorite: Bool = false, latitude: Double = -118.475601, longitude: Double = 33.987164, imageName: String = "") {
        self.name = name
        self.address = address
        self.state = state
        self.isFavorite = isFavorite
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.imageName = imageName
    }
    
    var image: Image {
        Image(imageName)
    }
    
    var locationCoordinate: CLLocationCoordinate2D {
         CLLocationCoordinate2D(
             latitude: latitude,
             longitude: longitude)
    }
}
