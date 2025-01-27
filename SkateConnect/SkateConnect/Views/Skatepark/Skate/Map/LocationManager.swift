//
//  LocationManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import CoreLocation
import Foundation
import MapKit
import NostrSDK
import SwiftUI

struct Mark: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct Lead: Identifiable, Equatable, Codable {
    static func == (lhs: Lead, rhs: Lead) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id = UUID()
    var name: String
    var icon: String
    var coordinate: CLLocationCoordinate2D
    var channelId: String
    var event: NostrEvent?
    var channel: Channel?
    
    // Optional colorHex to handle missing field during decoding
    var colorHex: String?
    
    var color: Color {
        get {
            Color(hex: colorHex ?? "#FF0000") ?? .red
        }
        set {
            colorHex = newValue.toHex()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, coordinate, channelId, event, channel, colorHex
    }
    
    init(id: UUID = UUID(), name: String, icon: String, coordinate: CLLocationCoordinate2D, channelId: String, event: NostrEvent?, channel: Channel?, color: Color) {
        self.id = id
        self.name = name
        self.icon = icon
        self.coordinate = coordinate
        self.channelId = channelId
        self.event = event
        self.channel = channel
        self.colorHex = color.toHex()
    }
}

public struct Defaults {
    public static let latitudinalMeters = 48.0
    public static let longitudinalMeters = 48.0
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
        
    @Published private var navigation: Navigation?
    
    @Published var currentLocation: CLLocation?
    
    @Published var pinCoordinate: CLLocationCoordinate2D?

    @Published var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppData().landmarks[0].locationCoordinate.latitude, longitude: AppData().landmarks[0].locationCoordinate.longitude),
                                                  latitudinalMeters: Defaults.latitudinalMeters,
                                                  longitudinalMeters: Defaults.longitudinalMeters)
    
    @Published var mapPosition = MapCameraPosition.region(MKCoordinateRegion())
    
    private var isLocationManagerInitialized = false 

    override init() {
        super.init()
        
        if let loadedRegion = loadMapRegion() {
            mapRegion = loadedRegion
        }
        mapPosition = MapCameraPosition.region(mapRegion)
    }
    
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    // Save map region to UserDefaults
    func saveMapRegion() {
        let defaults = UserDefaults.standard
        defaults.set(mapRegion.center.latitude, forKey: "mapCenterLatitude")
        defaults.set(mapRegion.center.longitude, forKey: "mapCenterLongitude")
        defaults.set(mapRegion.span.latitudeDelta, forKey: "mapLatitudeDelta")
        defaults.set(mapRegion.span.longitudeDelta, forKey: "mapLongitudeDelta")
    }
    
    // Load map region from UserDefaults
    func loadMapRegion() -> MKCoordinateRegion? {
        let defaults = UserDefaults.standard
        guard let latitude = defaults.object(forKey: "mapCenterLatitude") as? Double,
              let longitude = defaults.object(forKey: "mapCenterLongitude") as? Double,
              let latDelta = defaults.object(forKey: "mapLatitudeDelta") as? Double,
              let longDelta = defaults.object(forKey: "mapLongitudeDelta") as? Double else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(
                latitude: AppData().landmarks[0].locationCoordinate.latitude,
                longitude: AppData().landmarks[0].locationCoordinate.longitude),
                                      latitudinalMeters: Defaults.latitudinalMeters,
                                      longitudinalMeters: Defaults.longitudinalMeters
            )
        }
        
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: longDelta))
    }
    
    // Update the map region and save it
    func updateMapRegion(with coordinate: CLLocationCoordinate2D) {
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: Defaults.latitudinalMeters,
            longitudinalMeters: Defaults.longitudinalMeters
        )
        
        mapPosition = MapCameraPosition.region(mapRegion)
        saveMapRegion()
    }
    
    // Update map region on user interaction and save it
    func updateMapRegionOnUserInteraction(region: MKCoordinateRegion) {
        mapRegion = region
        mapPosition = MapCameraPosition.region(region)
        
        saveMapRegion()
    }
    
    // Ensure location services are only checked once, and state changes are throttled
    func checkIfLocationIsEnabled() {
        if isLocationManagerInitialized {
            return // Prevent initializing location manager multiple times
        }
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.delegate = self
            locationManager?.startUpdatingLocation() // Start updating location only if not already started
            isLocationManagerInitialized = true // Mark as initialized
        } else {
            print("Location services are disabled. Show an alert to the user.")
        }
    }
    
    // Handle location authorization status change
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let previousAuthorizationStatus = manager.authorizationStatus
        manager.requestWhenInUseAuthorization()
        if manager.authorizationStatus != previousAuthorizationStatus {
            checkLocationAuthorization()
        }
    }
    
    private func checkLocationAuthorization() {
        guard let location = locationManager else {
            return
        }
        
        switch location.authorizationStatus {
        case .notDetermined:
            print("Location authorization is not determined.")
        case .restricted:
            print("Location is restricted.")
        case .denied:
            print("Location permission denied.")
        case .authorizedAlways, .authorizedWhenInUse:
            if let location = location.location {
                updateMapRegion(with: location.coordinate)
            }
        default:
            break
        }
    }
    
    // Update the current location and handle state updates efficiently
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if ((navigation?.isLocationUpdatePaused) != nil) {
            return
        }
            
        guard let location = locations.last else { return }
        
        // Throttle the state update to avoid frequent re-renders
        if currentLocation == nil || (location.coordinate.latitude != currentLocation?.coordinate.latitude ||
                                      location.coordinate.longitude != currentLocation?.coordinate.longitude) {
            currentLocation = location // Update only if there's a meaningful change
        }
    }
    
    func panMapToCachedCoordinate() {
        if let coordinate = navigation?.coordinate {
            updateMapRegion(with: CLLocationCoordinate2D(
                latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }
    
    func panMapToCachedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        if let navigation = navigation {
            navigation.coordinate = coordinate
            self.panMapToCachedCoordinate()
        }
    }

    // Handle spot notification
    func handleGoToSpotNotification(_ notification: Notification) {
        guard let spot = notification.object as? Spot else {
            print("Received goToSpot notification, but no valid Spot object was found.")
            return
        }
        
        let locationCoordinate = spot.locationCoordinate
        self.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
        
        if spot.channelId.isEmpty {
            pinCoordinate = spot.locationCoordinate
        }
    }
}

