//
//  SkateView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Combine
import ConnectFramework
import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct SkateView: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var apiService: API
    @EnvironmentObject private var channelViewManager: ChannelViewManager
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var lobby: Lobby
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    
    @State private var showMenu = false
    @State private var selectedLead: Lead? = nil
    @State private var isInviteCopied = false
    @State private var isLinkCopied = false
    
    @Query private var spots: [Spot]
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack {
            SkateMapView()
                .environmentObject(dataManager)
                .environmentObject(lobby)
                .environmentObject(network)
                .overlay(
                    OverlayView(isInviteCopied: $stateManager.isInviteCopied, isLinkCopied: $stateManager.isLinkCopied)
                        .environmentObject(apiService)
                        .environmentObject(network)
                )
            
            BottomControlsView()
                .environmentObject(locationManager)
                .environmentObject(navigation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToCoordinate)) { _ in
            if let locationCoordinate = navigation.coordinate {
                locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                stateManager.addMarker(at: locationCoordinate, spots: spots)
            }
        }
        .task() {
            apiService.fetchLeads()
            lobby.setupLeads(spots: spots)
            
            apiService.fetchKeys()
        }
    }
    
    func panMapToCachedCoordinate(_ coordinate: CLLocationCoordinate2D) {
        navigation.coordinate = coordinate
        locationManager.panMapToCachedCoordinate()
    }
}

#Preview {
    SkateView().environment(AppData())
}
