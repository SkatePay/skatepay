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
    @Query private var spots: [Spot]
    
    @EnvironmentObject var viewModel: ContentViewModel
    
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject private var apiService = ApiService.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    @StateObject var locationManager = LocationManager()
    
    @State private var showingAlert = false
    @State private var isShowingLeadOptions = false
    @State private var isShowingLoadingOverlay = true
    
    @State var channelId = ""
    
    func handleLongPress(lead: Lead) {
        print("Long press detected on lead: \(lead.name)")
    }
    
    func overlayView() -> some View {
        GeometryReader { geometry in
            if isShowingLoadingOverlay {
                HStack {
                    Text(apiService.debugOutput())
                        .foregroundColor(.white)
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
                .position(x: geometry.size.width / 2, y: 16)  // Position at top
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigation.path) {
            VStack {
                MapReader { proxy in
                    Map(position: $locationManager.mapPosition) {
                        //                        UserAnnotation()
                        // Marks
                        ForEach(locationManager.marks) { mark in
                            Marker(mark.name, coordinate: mark.coordinate)
                                .tint(.orange)
                        }
                        // Leads
                        ForEach(Array(lobby.leads.values)) { lead in
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
                                            channelId = lead.channelId
                                            navigation.isShowingChannelView.toggle()
                                        }
                                )
                            }
                        }
                    }
                    .onAppear{
                        locationManager.checkIfLocationIsEnabled()
                    }
                    .onTapGesture { position in
                        if let coordinate = proxy.convert(position, from: .local) {
                            locationManager.marks = []
                            addMarker(at: coordinate)
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
                            locationManager.updateMapRegion(with: location) // Move map to user's current location
                        } else {
                            print("Current location not available.")
                        }
                    }) {
                        Text("Find Me")
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
                        Text("🔎")
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
                        }.alert("Mark cleared.", isPresented: $showingAlert) {
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
            .fullScreenCover(isPresented: $navigation.isShowingDirectory) {
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
            .fullScreenCover(isPresented: $navigation.isShowingChannelView) {
                if self.channelId.isEmpty {
                    Text("No lead available at this index.")
                } else {
                    NavigationView {
                        ChannelView(channelId: self.channelId)
                    }
                }
            }
            .fullScreenCover(isPresented: $navigation.isShowingSearch) {
                NavigationView {
                    SearchView()
                        .navigationBarTitle("Search")
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
                    // Need to deprecate in favor of nostr channel
                    if (event.id == AppData().landmarks[0].eventId ) {
                        return
                    }
                    
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
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .joinChat)) { notification in
                if  let locationCoordinate = navigation.coordinate {
                    locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                }
                
                navigation.isShowingChannelView = true
                
                if let channelId = notification.userInfo?["channelId"] as? String {
                    self.channelId = channelId
                }
            }
            .onReceive(viewModel.$observedSpot) { observedSpot in
                DispatchQueue.main.async {
                    viewModel.observedSpot.spot = nil
                    self.locationManager.clearMarks()
                }
            }
//            .onReceive(apiService.$leads) { leads in
//                DispatchQueue.main.async {
//                    for lead in leads {
//                        let eventId = lead.channelId
//                        self.lobby.leads[eventId] = lead
//                    }
//                }
//            }
            .onAppear() {
//                self.subscribeToChannelCreation()
                self.locationManager.checkIfLocationIsEnabled()
                self.apiService.fetchLeads()
                self.lobby.setupLeads(spots: spots)
            }
        }
//        .onAppear(perform: subscribeToChannelCreation)
    }
    
    @State private var channelCreationEvent: NostrEvent? // Store the event
    private var subscriptions = Set<AnyCancellable>() // Combine subscriptions

//    private func subscribeToChannelCreation() {
////        // Subscribe to channel creation events
////        NotificationCenter.default.publisher(for: .newChannelCreated)
////            .sink { [weak self] notification in
////                if let nostrEvent = notification.object as? NostrEvent {
////                    self?.channelCreationEvent = nostrEvent
////                }
////            }
////            .store(in: &subscriptions)
//        NotificationCenter.default.addObserver(
//            forName: .newChannelCreated,
//            object: nil,
//            queue: .main
//        ) { _ in
//            self.feedDelegate.updateSubscription()
//        }
//    }

    private func handleNewChannelCreationEvent(_ event: NostrEvent) {
        // Update state with the received event
        channelCreationEvent = event

        // Any other state or UI updates related to the new channel creation can go here
        print("Received channel creation event: \(event)")
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
        
        navigation.isShowingMarkerOptions = true
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
