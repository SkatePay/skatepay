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

struct MarqueeText: View {
    let text: String
    @State private var offsetX: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        Text(text)
            .font(.headline)
            .bold()
            .foregroundColor(.white)
            .offset(x: offsetX)
            .onAppear {
                let baseAnimation = Animation.linear(duration: 8.0).repeatForever(autoreverses: false)
                withAnimation(baseAnimation) {
                    offsetX = -UIScreen.main.bounds.width
                }
            }
    }
}

struct DebugView<Content: View>: View {
    let content: Content
    let id = UUID()
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        print("Creating DebugView with ID: \(id)")
    }
    
    var body: some View {
        content.onAppear {
            print("DebugView with ID: \(id) appeared")
        }
    }
}

struct SkateView: View {
    @Query private var spots: [Spot]
        
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject private var apiService = API.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    @StateObject var locationManager = LocationManager()
    
    @State private var showingAlert = false
    @State private var isShowingLeadOptions = false
    @State private var isShowingLoadingOverlay = true
    
    @State var channelId: String = ""
    
    @State var pinCoordinate: CLLocationCoordinate2D?
    
    func handleLongPress(lead: Lead) {
        print("Long press detected on lead: \(lead.name)")
    }
    
    func overlayView() -> some View {
        GeometryReader { geometry in
            if isShowingLoadingOverlay {
                HStack {
                    MarqueeText(text: apiService.debugOutput())
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isShowingLoadingOverlay = false
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
    }
    
    var body: some View {
        VStack {
            MapReader { proxy in
                Map(position: $locationManager.mapPosition) {
                    UserAnnotation()
                    
                    if let coordinate = self.pinCoordinate {
                        Annotation("❌", coordinate: coordinate) {
                        }
                    }
                    
                    // Marks
                    ForEach(locationManager.marks) { mark in
                        Marker(mark.name, coordinate: mark.coordinate)
                            .tint(.orange)
                    }
                    // Leads
                    ForEach(lobby.leads) { lead in
                        Annotation(lead.name, coordinate:  lead.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle()
                                    .foregroundStyle(.indigo.opacity(0.5))
                                    .frame(width: 80, height: 80)
                                
                                Text(lead.icon)
                                    .font(.system(size: 24))
                                    .symbolEffect(.variableColor)
                                    .padding()
                                    .foregroundStyle(.white)
                                    .background(Color.indigo)
                                    .clipShape(Circle())
                            }
                            .gesture(
                                LongPressGesture(minimumDuration: 1.0)
                                    .onEnded { _ in
                                        //                                           handleLongPress(lead: lead)
                                    }
                                    .onChanged { state in
                                        navigation.joinChat(channelId: lead.channelId)
                                    }

                            )
                        }
                    }
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    locationManager.updateMapRegionOnUserInteraction(region: context.region)
                }
                .onAppear{
                    locationManager.checkIfLocationIsEnabled()
                }
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        locationManager.marks = []
                        addMarker(at: coordinate)
                        navigation.isShowingMarkerOptions = true
                    }
                }
                .overlay(
                    overlayView()
                        .opacity(isShowingLoadingOverlay ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isShowingLoadingOverlay)
                )
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    if let location = locationManager.currentLocation?.coordinate {
                        locationManager.updateMapRegion(with: location)
                    } else {
                        print("Current location not available.")
                    }
                }) {
                    Text("🔎")
                        .font(.headline)
                        .padding(8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    navigation.isShowingDirectory = true
                    
                }) {
                    Text("Skateparks")
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    navigation.isShowingSearch.toggle()
                    
                }) {
                    Text("🌐")
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                if (!locationManager.marks.isEmpty) {
                    Button(action: {
                        locationManager.marks = []
                    }) {
                        Text("Clear Mark")
                            .padding(8)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .alert("Mark cleared.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) { }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $navigation.isShowingMarkerOptions) {
            MarkerOptions(marks: locationManager.marks)
        }
        .sheet(isPresented: $isShowingLeadOptions) {
            LeadOptions()
        }
        .fullScreenCover(isPresented: $navigation.isShowingChannelView) {
            if self.channelId.isEmpty {
                Text("No lead available at this index.")
            } else {
                DebugView() {
                    NavigationView {
                        ChannelView(channelId: self.channelId)
                    }
                }

            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingDirectory) {
            DebugView() {
                NavigationView {
                    LandmarkDirectory()
                        .navigationBarTitle("🛹 Skateparks")
                        .navigationBarItems(leading:
                                                Button(action: {
                            navigation.isShowingDirectory = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Map")
                                Spacer()
                            }
                        })
                }
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingSearch) {
            NavigationView {
                SearchView()
                    .navigationBarTitle("🌐 Network")
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.isShowingSearch = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Map")
                            Spacer()
                        }
                    })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChannelCreated)) { notification in
            if let event = notification.object as? NostrEvent {
                let lead = createLead(from: event)
                self.dataManager.saveSpotForLead(lead)
                self.locationManager.marks = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToLandmark)) { _ in
            if  let locationCoordinate = navigation.landmark?.locationCoordinate {
                locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToCoordinate)) { _ in
            if  let locationCoordinate = navigation.coordinate {
                locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                
                addMarker(at: locationCoordinate)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToSpot)) { notification in
            handleGoToSpotNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .joinChat)) { notification in
            if  let locationCoordinate = navigation.coordinate {
                locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
            }
            
            if let channelId = notification.userInfo?["channelId"] as? String {
                self.channelId = channelId
                navigation.isShowingChannelView.toggle()
            }
        }
        .onReceive(lobby.$observedSpot) { observedSpot in
            DispatchQueue.main.async {
                lobby.observedSpot.spot = nil
                self.locationManager.clearMarks()
            }
        }
        .task() {
            DispatchQueue.main.async {
                self.locationManager.checkIfLocationIsEnabled()
            }
            
            self.apiService.fetchLeads()
            self.lobby.setupLeads(spots: spots)
            
            self.apiService.fetchKeys()
        }
    }
    
    
    func handleGoToSpotNotification(_ notification: Notification) {
        guard let spot = notification.object as? Spot else {
            print("Received goToSpot notification, but no valid Spot object was found.")
            return
        }
        
        let locationCoordinate = spot.locationCoordinate
        locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
        
        if spot.channelId.isEmpty {
            self.pinCoordinate = spot.locationCoordinate
        }
    }
    
    func addMarker(at coordinate: CLLocationCoordinate2D) {
        let mark = Mark(name: "Marker \(spots.count + 1)", coordinate: coordinate)
        locationManager.marks.append(mark)
        
        let nearbyLandmarks = getNearbyLandmarks(for: coordinate)
        if !nearbyLandmarks.isEmpty {
            print("Nearby landmarks: \(nearbyLandmarks.map { $0.name })")
        } else {
            print("No nearby landmarks")
        }
    }
    
    func getNearbyLandmarks(for coordinate: CLLocationCoordinate2D) -> [Landmark] {
        let markerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let landmarks = AppData().landmarks
        
        return landmarks.filter { landmark in
            let landmarkLocation = CLLocation(latitude: landmark.locationCoordinate.latitude, longitude: landmark.locationCoordinate.longitude)
            let distance = markerLocation.distance(from: landmarkLocation)
            
            return distance <= 32
        }
    }
    
    func convertPointToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D? {
        let mapView = MKMapView(frame: .zero)
        mapView.setRegion(locationManager.mapRegion, animated: false)
        
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        return coordinate
    }
}

#Preview {
    SkateView().environment(AppData())
}
