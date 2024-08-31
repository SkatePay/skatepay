//
//  Park.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct Landmark: Hashable, Codable, Identifiable {
    var id: Int
    var name: String
    
    var park: String
    
    var address: String
    var state: String
    
    var description: String
    
    private var imageName: String
    var image: Image {
        Image(imageName)
    }
    
    private var coordinates: Coordinates
    
    struct Coordinates: Hashable, Codable {
        var latitude: Double
        var longitude: Double
    }
    var locationCoordinate: CLLocationCoordinate2D {
         CLLocationCoordinate2D(
             latitude: coordinates.latitude,
             longitude: coordinates.longitude)
    }
}
