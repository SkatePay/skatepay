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
                .overlay(
                    OverlayView(isInviteCopied: $stateManager.isInviteCopied, isLinkCopied: $stateManager.isLinkCopied)
                )
            
            BottomControlsView()
                .environmentObject(locationManager)
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .channel },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            if let channelId = navigation.channelId {
                NavigationView {
                    DebugView {
                        ChannelView(channelId: channelId)
                            .environmentObject(dataManager)
                            .environmentObject(navigation)
                            .environmentObject(network)
                            .onDisappear {
                                locationManager.panMapToCachedCoordinate()
                            }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .camera },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            NavigationView {
                CameraView()
                    .environmentObject(navigation)
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .directory },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            NavigationView {
                LandmarkDirectory()
                    .environmentObject(dataManager)
                    .environmentObject(navigation)
                    .environmentObject(network)
                    .navigationBarTitle("🏁 Skateparks")
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.activeSheet = .none
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Map")
                            Spacer()
                        }
                    })
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .search },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            NavigationView {
                SearchView()
                    .environmentObject(navigation)
                    .navigationBarTitle("🎯 Explore Network 🕸️")
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.activeSheet = .none
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Map")
                            Spacer()
                        }
                    })
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .createChannel },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            NavigationView {
                CreateChannel(mark: stateManager.marks[0])
                    .environmentObject(navigation)
                    .environmentObject(network)
                    .environmentObject(stateManager)
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.activeSheet = .none
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Spacer()
                        }
                    })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createdChannelForOutbound)) { notification in
            if let event = notification.object as? NostrEvent {
                if let lead = createLead(from: event) {
                    dataManager.saveSpotForLead(lead)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createdChannelForInbound)) { notification in
            if let event = notification.object as? NostrEvent {
                if let lead = createLead(from: event) {
                    dataManager.saveSpotForLead(lead, note: "invite")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToLandmark)) { _ in
            if let locationCoordinate = navigation.landmark?.locationCoordinate {
                locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToCoordinate)) { _ in
            if let locationCoordinate = navigation.coordinate {
               locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                
                stateManager.addMarker(at: locationCoordinate, spots: spots)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToSpot)) { notification in
            locationManager.handleGoToSpotNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .joinChannel)) { notification in
            if let channelId = notification.userInfo?["channelId"] as? String {
                if let spot = dataManager.findSpotForChannelId(channelId) {
                    navigation.coordinate = spot.locationCoordinate
                }
                
                locationManager.panMapToCachedCoordinate()
                channelViewManager.openChannel(channelId: channelId)
            }
        }
        .task() {
            DispatchQueue.main.async {
                locationManager.checkIfLocationIsEnabled()
            }
            
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
