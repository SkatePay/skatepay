//
//  LocationManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/21/24.
//

import os

import Combine
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
    var note: String
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
        case id, name, icon, note, coordinate, channelId, event, channel, colorHex
    }
    
    init(id: UUID = UUID(), name: String, icon: String, note: String, coordinate: CLLocationCoordinate2D, channelId: String, event: NostrEvent?, channel: Channel?, color: Color) {
        self.id = id
        self.name = name
        self.icon = icon
        self.note = note
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
    let log = OSLog(subsystem: "SkateConnect", category: "Location Manager")

    private var locationManager: CLLocationManager?
        
    @Published private var navigation: Navigation?
    
    @Published var currentLocation: CLLocation?
    
    @Published var pinCoordinate: CLLocationCoordinate2D?

    @Published var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppData().landmarks[0].locationCoordinate.latitude, longitude: AppData().landmarks[0].locationCoordinate.longitude),
                                                  latitudinalMeters: Defaults.latitudinalMeters,
                                                  longitudinalMeters: Defaults.longitudinalMeters)
    
    @Published var mapPosition = MapCameraPosition.region(MKCoordinateRegion())
    
    private var cancellables = Set<AnyCancellable>()

    
    override init() {
        super.init()
        
        if let loadedRegion = loadMapRegion() {
            mapRegion = loadedRegion
        }
        mapPosition = MapCameraPosition.region(mapRegion)
        
        startListening()
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
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.delegate = self
            locationManager?.startUpdatingLocation()
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
    
    private var lastUpdateTime: Date?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let navigation = navigation else { return }
        
        if (navigation.tab != .map) { return }
        
        if (!navigation.path.isEmpty) { return }
        
        // Throttled update
        guard let location = locations.last else { return }
        
        let now = Date()
        
        if let lastUpdate = lastUpdateTime, now.timeIntervalSince(lastUpdate) < 1 {
            return
        }
        
        lastUpdateTime = now
        
        if currentLocation == nil || (location.coordinate.latitude != currentLocation?.coordinate.latitude ||
                                      location.coordinate.longitude != currentLocation?.coordinate.longitude) {
            currentLocation = location
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

    func handleGoToSpotNotification(_ notification: Notification) {
        guard let spot = notification.object as? Spot else {
            os_log("🔥 can't get spot", log: log, type: .error)
            return
        }
        
        os_log("⏳ panning to spot %@", log: log, type: .info, spot.name)
        
        let locationCoordinate = spot.locationCoordinate
        
        // Update the map region to the spot's location
        updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
        
        // Pan the map to the new location
        mapPosition = MapCameraPosition.region(MKCoordinateRegion(
            center: locationCoordinate,
            latitudinalMeters: Defaults.latitudinalMeters,
            longitudinalMeters: Defaults.longitudinalMeters
        ))
        
        // Set the pin coordinate if the channelId is empty
        if spot.channelId.isEmpty {
            pinCoordinate = spot.locationCoordinate
        }
    }
    
    func handleGoToLandmarkNotification(_ notification: Notification) {
        guard let landmark = notification.object as? Landmark else {
            print("Received goToSpot notification, but no valid Spot object was found.")
            return
        }
        
        let locationCoordinate = landmark.locationCoordinate
        
        // Update the map region to the spot's location
        updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
        
        // Pan the map to the new location
        mapPosition = MapCameraPosition.region(MKCoordinateRegion(
            center: locationCoordinate,
            latitudinalMeters: Defaults.latitudinalMeters,
            longitudinalMeters: Defaults.longitudinalMeters
        ))
    }
    
    func startListening() {
        NotificationCenter.default.publisher(for: .goToLandmark)
            .sink { [weak self] notification in
                self?.handleGoToLandmarkNotification(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .goToSpot)
            .sink { [weak self] notification in
                self?.handleGoToSpotNotification(notification)
            }
            .store(in: &cancellables)
    }
}

