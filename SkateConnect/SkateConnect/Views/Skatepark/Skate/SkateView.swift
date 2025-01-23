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
    
    @State private var showMenu = false
    @State private var selectedLead: Lead? = nil
    @State private var isInviteCopied = false
    @State private var isLinkCopied = false
    
    @Query private var spots: [Spot]
    
    @StateObject var channelManager = ChannelViewManager.shared
    
    @ObservedObject private var stateManager = StateManager()

    init() {
        print("SkateView initialized at \(Date())")
    }
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium) // Haptic feedback generator

    func handleLongPress(lead: Lead) {
        print("Long press detected on lead: \(lead.name)")
    }
    
    func overlayView() -> some View {
        ZStack {
            GeometryReader { geometry in
                if stateManager.isShowingLoadingOverlay {
                    HStack {
                        MarqueeText(text: stateManager.apiService.debugOutput())
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                stateManager.isShowingLoadingOverlay = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: 16)
                }
                
                // Centered "Invite copied!" message
                if isInviteCopied {
                    Text("Invite copied! Paste in DM or a channel.")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .zIndex(1) // Bring this view on top
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onAppear {
                            // Hide after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isInviteCopied = false
                                }
                            }
                        }
                }
                
                if isLinkCopied {
                    Text("Link copied. Share it with friends!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .zIndex(1) // Bring this view on top
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onAppear {
                            // Hide after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isLinkCopied = false
                                }
                            }
                        }
                }
            }
            
            if !stateManager.navigation.marks.isEmpty {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        HStack {
                            Text("Start Channel")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                stateManager.navigation.isShowingCreateChannel.toggle()
                            }) {
                                Image(systemName: "shareplay")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Text("Save Spot")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                Task {
                                    for mark in stateManager.navigation.marks {
                                        let spot = Spot(
                                            name: mark.name,
                                            address: "",
                                            state: "",
                                            icon: "",
                                            note: "private",
                                            latitude: mark.coordinate.latitude,
                                            longitude: mark.coordinate.longitude
                                        )
                                        context.insert(spot)
                                        stateManager.navigation.goToSpot(spot: spot)
                                    }
                                }
                                stateManager.showingAlertForSpotBookmark.toggle()
                            }) {
                                Image(systemName: "bookmark.circle.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .alert("Spot bookmarked", isPresented: $stateManager.showingAlertForSpotBookmark) {
                                Button("OK", role: .cancel) {
                                    stateManager.navigation.marks = []
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Text("Clear Mark")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                stateManager.navigation.marks = []
                            }) {
                                Image(systemName: "clear.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                    }
                    .padding(.trailing, 20)
                    
                    Spacer()
                }
            }
        }
        .animation(.easeInOut, value: isInviteCopied)
    }
    
    func createActionSheetForLead(_ lead: Lead) -> ActionSheet {
        
        let spot = stateManager.dataManager.findSpotForChannelId(lead.channelId)
        
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
                    stateManager.panMapToCachedCoordinate(lead.coordinate)
                    channelManager.openChannel(channelId: lead.channelId)
                },
                .default(Text("Camera")) {
                    // Handle camera action
                    stateManager.navigation.isShowingCameraView = true
                    stateManager.navigation.channelId = lead.channelId
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
                    channelManager.deleteChannelWithId(lead.channelId)
                    stateManager.dataManager.removeSpotForChannelId(lead.channelId)
                } : nil,
                .cancel()
            ].compactMap { $0 } // Remove any nil values
        )
    }
    
    var body: some View {
        VStack {
            MapReader { proxy in
                Map(position: $stateManager.locationManager.mapPosition) {
                    UserAnnotation()
                    
                    if let coordinate = stateManager.pinCoordinate {
                        Annotation("❌", coordinate: coordinate) {
                        }
                    }
                    
                    // Marks
                    ForEach(stateManager.navigation.marks) { mark in
                        Marker(mark.name, coordinate: mark.coordinate)
                            .tint(.orange)
                    }
                    
                    // Leads
                    ForEach(stateManager.lobby.leads) { lead in
                        Annotation(lead.name, coordinate: lead.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle()
                                    .foregroundStyle(lead.color.opacity(0.5))
                                    .frame(width: 80, height: 80)
                                
                                Text(lead.icon)
                                    .font(.system(size: 24))
                                    .symbolEffect(.variableColor)
                                    .padding()
                                    .foregroundStyle(.white)
                                    .background(lead.color)
                                    .clipShape(Circle())
                            }
                            .gesture(
                                LongPressGesture(minimumDuration: 1.5)
                                    .simultaneously(with: DragGesture(minimumDistance: 0))
                                    .onEnded { value in
                                        // Trigger haptic feedback
                                            
                                        feedbackGenerator.impactOccurred()
                                        
                                        // Set the selected lead and show the menu
                                        self.selectedLead = lead
                                        self.showMenu = true
                                    
                                    }
                            )
                            .actionSheet(isPresented: $showMenu) {
                                guard let lead = selectedLead else {
                                    return ActionSheet(title: Text("Error"), message: Text("No lead selected."), buttons: [.cancel()])
                                }
                                
                                return createActionSheetForLead(lead)
                            }
                        }
                    }
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    stateManager.locationManager.updateMapRegionOnUserInteraction(region: context.region)
                }
                .onAppear{
                    stateManager.locationManager.checkIfLocationIsEnabled()
                }
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        stateManager.navigation.marks = []
                        stateManager.addMarker(at: coordinate, spots: spots)

                        stateManager.locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                    }
                }
                .overlay(
                    overlayView()
                        .animation(.easeInOut(duration: 0.3), value: stateManager.isShowingLoadingOverlay)
                )
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    if let coordinate = stateManager.locationManager.currentLocation?.coordinate {
                        stateManager.panMapToCachedCoordinate(coordinate)
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
                    stateManager.navigation.isShowingDirectory = true
                    
                }) {
                    Text("Skateparks")
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    stateManager.navigation.isShowingSearch.toggle()
                }) {
                    Text("🔎")
                        .padding(8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $channelManager.isShowingChannelView) {
            if let channelId = channelManager.channelId {
                NavigationView {
                    DebugView {
                        ChannelView(channelId: channelId)
                            .onDisappear {
                                stateManager.locationManager.panMapToCachedCoordinate()
                                channelManager.isShowingChannelView = false // Reset state
                            }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $stateManager.navigation.isShowingCameraView) {
            NavigationView {
                CameraView()
            }
        }
        .fullScreenCover(isPresented: $stateManager.navigation.isShowingDirectory) {
            NavigationView {
                LandmarkDirectory()
                    .navigationBarTitle("🏁 Skateparks")
                    .navigationBarItems(leading:
                                            Button(action: {
                        stateManager.navigation.isShowingDirectory = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Map")
                            Spacer()
                        }
                    })
            }
        }
        .fullScreenCover(isPresented: $stateManager.navigation.isShowingSearch) {
            NavigationView {
                SearchView()
                    .navigationBarTitle("🎯 Explore Network 🕸️")
                    .navigationBarItems(leading:
                                            Button(action: {
                        stateManager.navigation.isShowingSearch = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Map")
                            Spacer()
                        }
                    })
            }
        }
        .fullScreenCover(isPresented: $stateManager.navigation.isShowingCreateChannel) {
            NavigationView {
                CreateChannel(mark: stateManager.navigation.marks[0])
                    .navigationBarItems(leading:
                                            Button(action: {
                        stateManager.navigation.isShowingCreateChannel = false
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
                    stateManager.dataManager.saveSpotForLead(lead)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createdChannelForInbound)) { notification in
            if let event = notification.object as? NostrEvent {
                if let lead = createLead(from: event) {
                    stateManager.dataManager.saveSpotForLead(lead, note: "invite")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToLandmark)) { _ in
            if let locationCoordinate = stateManager.navigation.landmark?.locationCoordinate {
                stateManager.locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToCoordinate)) { _ in
            if let locationCoordinate = stateManager.navigation.coordinate {
                stateManager.locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                
                stateManager.addMarker(at: locationCoordinate, spots: spots)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToSpot)) { notification in
            stateManager.handleGoToSpotNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .joinChannel)) { notification in
            if let channelId = notification.userInfo?["channelId"] as? String {
                if let spot = stateManager.dataManager.findSpotForChannelId(channelId) {
                    stateManager.navigation.coordinate = spot.locationCoordinate
                }

                stateManager.locationManager.panMapToCachedCoordinate()
                stateManager.navigation.goToChannelWithId(channelId)
            }
        }
        .task() {
            DispatchQueue.main.async {
                stateManager.locationManager.checkIfLocationIsEnabled()
            }
            
            stateManager.apiService.fetchLeads()
            stateManager.lobby.setupLeads(spots: spots)
            
            stateManager.apiService.fetchKeys()
        }
    }
}

//struct SkateView: View {
//    init() {
//        print("SkateView initialized at \(Date())")
//    }
//    
//    var body: some View {
//        VStack {
//            
//            }
//        }
//}


#Preview {
    SkateView().environment(AppData())
}
