//
//  BottomControlsView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/26/25.
//

import Combine
import ConnectFramework
import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct BottomControlsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigation: Navigation
    
    let landmarks = AppData().landmarks;
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                // Check if coordinates exist in UserDefaults
                if let jsonString = UserDefaults.standard.string(forKey: UserDefaults.Keys.coordinates) {
                    // If coordinates exist, convert and use them
                    guard let coordinates = convertStringToCoordinate(jsonString) else { return }
                    
                    panMapToCachedCoordinate(coordinates)
                } else {
                    // If coordinates don't exist, use the first landmark's coordinates
                    let coordinate = landmarks[0].locationCoordinate
                    panMapToCachedCoordinate(coordinate)
                }
            }) {
                Text("🏛️")
                    .font(.headline)
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                if let coordinate = locationManager.currentLocation?.coordinate {
                    panMapToCachedCoordinate(coordinate)
                } else {
                    print("Current location not available.")
                }
            }) {
                Text("🌐")
                    .font(.headline)
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                navigation.path.append(NavigationPathType.landmarkDirectory)
            }) {
                Text("Skateparks")
                    .padding(8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                navigation.path.append(NavigationPathType.search)
            }) {
                Text("🔎")
                    .padding(8)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                navigation.path.append(NavigationPathType.deckTracker)
            }) {
                Text("🛹")
                    .padding(8)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    func panMapToCachedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        navigation.coordinate = coordinate
        locationManager.panMapToCachedCoordinate()
    }
}
