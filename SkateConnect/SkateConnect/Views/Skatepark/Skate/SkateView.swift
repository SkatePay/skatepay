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
    
    @Query private var spots: [Spot]
    
    @StateObject var channelManager = ChannelManager()
    
    @ObservedObject private var stateManager = StateManager()
    
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
                                Image(systemName: "message.circle.fill")
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
                                            note: "",
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
                                let color: Color = {
                                    if let event = lead.event, stateManager.wallet.isMe(hex: event.pubkey) {
                                        return Color.orange
                                    } else {
                                        return Color.indigo
                                    }
                                }()
                                
                                Circle()
                                    .foregroundStyle(color.opacity(0.5))
                                    .frame(width: 80, height: 80)
                                
                                Text(lead.icon)
                                    .font(.system(size: 24))
                                    .symbolEffect(.variableColor)
                                    .padding()
                                    .foregroundStyle(.white)
                                    .background(color)
                                    .clipShape(Circle())
                            }
                            .gesture(
                                LongPressGesture(minimumDuration: 1.0)
                                    .onEnded { _ in
                                    }
                                    .onChanged { state in
                                        stateManager.panMapToCachedCoordinate(lead.coordinate)
                                        channelManager.openChannel(channelId: lead.channelId)
                                    }
                            )
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
            if channelManager.channelId.isEmpty {
                Text("No lead available at this index.")
            } else {
                NavigationView {
                    ChannelView(channelId: channelManager.channelId)
                        .onDisappear {
                            stateManager.locationManager.panMapToCachedCoordinate()
                        }
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .newChannelCreated)) { notification in
            if let event = notification.object as? NostrEvent {
                let lead = createLead(from: event)
                stateManager.dataManager.saveSpotForLead(lead)
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

#Preview {
    SkateView().environment(AppData())
}
