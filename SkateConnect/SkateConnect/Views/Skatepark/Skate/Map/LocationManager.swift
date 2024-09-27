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
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    
    @Published var marks: [Mark] = []
    @Published var currentLocation: CLLocation?
    @Published var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppData().landmarks[0].locationCoordinate.latitude, longitude: AppData().landmarks[0].locationCoordinate.longitude), latitudinalMeters: 64, longitudinalMeters: 64)
    
    @Published var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppData().landmarks[0].locationCoordinate.latitude, longitude: AppData().landmarks[0].locationCoordinate.longitude), latitudinalMeters: 64, longitudinalMeters: 64)
    )
    
    func updateMapRegion(with coordinate: CLLocationCoordinate2D) {
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 64,
            longitudinalMeters: 64
        )
        
        mapPosition = MapCameraPosition.region(mapRegion)
    }
    
    func checkIfLocationIsEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager!.delegate = self
            locationManager?.startUpdatingLocation() // Start updating location
        } else {
            print("Show an alert letting them know this is off")
        }
    }
    
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
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 64,
                    longitudinalMeters: 64
                )
            }
            
        default:
            break
        }
    }
    
    // Update the currentLocation when a new location is received
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location // Update the current location
    }
    
    func clearMarks() {
        self.marks = []
    }
}
