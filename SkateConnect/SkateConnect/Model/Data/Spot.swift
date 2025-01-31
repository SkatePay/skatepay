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
    let name: String
        
    let address: String
    let state: String
    
    let icon: String = ""
    let note: String = ""
    
    let isFavorite: Bool
    
    let imageName: String
    
    var latitude: Double
    var longitude: Double
    
    var channelId: String
        
    init(name: String, address: String, state: String, icon: String, note: String, isFavorite: Bool = false, latitude: Double = -118.475601, longitude: Double = 33.987164, channelId: String = "", imageName: String = "") {
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
