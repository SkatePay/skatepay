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
    
    func createActionSheetForLead(_ lead: Lead) -> ActionSheet {
        
        let spot = dataManager.findSpotForChannelId(lead.channelId)
        
        var canBeRemoved = true
        
        // Safely unwrap the spot and check the note after the colon
        if let spot = spot, let note = spot.note.split(separator: ":").last.map(String.init) {
            if note == "public" {
                canBeRemoved = false
            }
        }
        
        return ActionSheet(
            title: Text("\(lead.name)"),
            message: Text("Choose an action for this channel."),
            buttons: [
                .default(Text("Open")) {
                    // Handle opening the channel
                    locationManager.panMapToCachedCoordinate(lead.coordinate)
                    channelViewManager.openChannel(channelId: lead.channelId)
                },
                .default(Text("Camera")) {
                    navigation.activeSheet = .camera
                    navigation.channelId = lead.channelId
                },
                .default(Text("Copy Link")) {
                    let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/channel/\(lead.channelId)"
                    UIPasteboard.general.string = customUrlString
                    
                    isLinkCopied = true
                },
                (lead.event != nil) ? .default(Text("Copy Invite")) {
                    var inviteString = lead.channelId
                    
                    if let event = lead.event {
                        if var channel = parseChannel(from: event) {
                            channel.event = event
                            if let ecryptedString = encryptChannelInviteToString(channel: channel) {
                                inviteString = ecryptedString
                            }
                        }
                    }
                    
                    UIPasteboard.general.string = "channel_invite:\(inviteString)"
                    
                    isInviteCopied = true
                } : nil,
                .default(Text("Open in Maps")) {
                    let coordinate = lead.coordinate
                    
                    let locationString = "\(coordinate.latitude),\(coordinate.longitude)"
                    if let url = URL(string: "http://maps.apple.com/?daddr=\(locationString)&dirflg=d") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                },
                // Conditionally include the Remove button
                canBeRemoved ? .destructive(Text("Remove")) {
                    channelViewManager.deleteChannelWithId(lead.channelId)
                    dataManager.removeSpotForChannelId(lead.channelId)
                } : nil,
                .cancel()
            ].compactMap { $0 } // Remove any nil values
        )
    }
    
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
