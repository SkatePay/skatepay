//
//  FloatingOverlayButton.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/14/25.
//

import Combine
import ConnectFramework
import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct FloatingOverlayButton: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigation: Navigation
    
    let landmarks = AppData().landmarks
    @State private var showFabMenu = false
    
    var body: some View {
        GeometryReader { geometry in
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        // FAB Button
                        Button(action: {
                            withAnimation {
                                showFabMenu.toggle()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                                .padding()
                        }
                        .background(GeometryReader { fabGeometry in
                            Color.clear
                                .preference(key: FABPositionKey.self, value: fabGeometry.frame(in: .global))
                        })
                        .onPreferenceChange(FABPositionKey.self) { fabFrame in
                            self.fabFrame = fabFrame
                        }
                        
                        // Expanded Menu
                        if showFabMenu {
                            // Vertical Stack on the Right (Existing Buttons)
                            VStack(spacing: 15) {
                                // Landmarks Button
                                Button(action: {
                                    if let jsonString = UserDefaults.standard.string(forKey: UserDefaults.Keys.coordinates) {
                                        guard let coordinates = convertStringToCoordinate(jsonString) else { return }
                                        panMapToCachedCoordinate(coordinates)
                                    } else {
                                        let coordinate = landmarks[0].locationCoordinate
                                        panMapToCachedCoordinate(coordinate)
                                    }
                                    showFabMenu = false
                                }) {
                                    Image(systemName: "building.columns.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                // Location Button
                                Button(action: {
                                    if let coordinate = locationManager.currentLocation?.coordinate {
                                        panMapToCachedCoordinate(coordinate)
                                    } else {
                                        print("Current location not available.")
                                    }
                                    showFabMenu = false
                                }) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                // Skateparks Button
                                Button(action: {
                                    navigation.path.append(NavigationPathType.landmarkDirectory)
                                    showFabMenu = false
                                }) {
                                    Image(systemName: "map.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.green)
                                        .clipShape(Circle())
                                }
                                
                                // Search Button
                                Button(action: {
                                    navigation.path.append(NavigationPathType.search)
                                    showFabMenu = false
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.purple)
                                        .clipShape(Circle())
                                }
                                
                                // Deck Tracker Button
                                Button(action: {
                                    navigation.path.append(NavigationPathType.deckTracker)
                                    showFabMenu = false
                                }) {
                                    Image(systemName: "skateboard.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.gray)
                                        .clipShape(Circle())
                                }
                            }
                            .offset(y: -(geometry.size.height * 0.3)) // 30% of screen height
                            .transition(.scale)
                            
                            // Camera Button Fanning Out to the Horizontal Center
                            Button(action: {
                                // Placeholder for camera logic
                                print("Camera tapped")
                                showFabMenu = false
                                navigation.path.append(NavigationPathType.camera)
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding(15)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .scaleEffect(1.3)
                            }
                            .offset(x: -(geometry.size.width / 2) + (fabFrame.width / 2), y: 0) // Precise centering
                            .transition(.scale)
                        }
                    }
                }
            }
        }
    }
    
    // Store the FAB's frame for precise centering
    @State private var fabFrame: CGRect = .zero
    
    func panMapToCachedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        navigation.coordinate = coordinate
        locationManager.panMapToCachedCoordinate()
    }
}

// Preference Key to get the FAB's frame
struct FABPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
