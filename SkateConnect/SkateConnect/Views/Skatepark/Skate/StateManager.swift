//
//  StateManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation
import Combine
import MapKit

class StateManager: ObservableObject {
    // Map properties
    @Published var pinCoordinate: CLLocationCoordinate2D?
    @Published var isShowingLoadingOverlay = true
    @Published var showingAlertForSpotBookmark = false
    
    @Published var marks: [Mark] = []
    
    // New properties for overlay and feedback
    @Published var isInviteCopied = false
    @Published var isLinkCopied = false
        
    func addMarker(at coordinate: CLLocationCoordinate2D, spots: [Spot]) {
        let mark = Mark(name: "Marker \(spots.count + 1)", coordinate: coordinate)
        self.marks.append(mark)
        
        let nearbyLandmarks = getNearbyLandmarks(for: coordinate)
        if !nearbyLandmarks.isEmpty {
            print("Nearby landmarks: \(nearbyLandmarks.map { $0.name })")
        } else {
            print("No nearby landmarks")
        }
    }

    func getNearbyLandmarks(for coordinate: CLLocationCoordinate2D) -> [Landmark] {
        let markerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let landmarks = AppData().landmarks
        
        return landmarks.filter { landmark in
            let landmarkLocation = CLLocation(latitude: landmark.locationCoordinate.latitude, longitude: landmark.locationCoordinate.longitude)
            let distance = markerLocation.distance(from: landmarkLocation)
            return distance <= 32
        }
    }
}
