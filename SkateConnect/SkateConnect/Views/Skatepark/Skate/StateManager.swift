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
    @Published var navigation = Navigation.shared
    @Published var locationManager = LocationManager.shared
    @Published var lobby = Lobby.shared
    @Published var wallet = Wallet.shared
    @Published var apiService = API.shared
    @Published var dataManager = DataManager.shared

    // Map properties
    @Published var pinCoordinate: CLLocationCoordinate2D?
    @Published var isShowingLoadingOverlay = true
    @Published var showingAlertForSpotBookmark = false
    
    // Methods to encapsulate functionality
    
    func addMarker(at coordinate: CLLocationCoordinate2D, spots: [Spot]) {
        let mark = Mark(name: "Marker \(spots.count + 1)", coordinate: coordinate)
        navigation.marks.append(mark)
        
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

    func panMapToCachedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        self.navigation.coordinate = coordinate
        self.locationManager.panMapToCachedCoordinate()
    }

    // Handle spot notification
    func handleGoToSpotNotification(_ notification: Notification) {
        guard let spot = notification.object as? Spot else {
            print("Received goToSpot notification, but no valid Spot object was found.")
            return
        }
        
        let locationCoordinate = spot.locationCoordinate
        locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
        
        if spot.channelId.isEmpty {
            pinCoordinate = spot.locationCoordinate
        }
    }
}
