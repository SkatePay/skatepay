//
//  SkateView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct Mark: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct Lead: Identifiable, Equatable {
    static func == (lhs: Lead, rhs: Lead) -> Bool {
        return lhs.id == rhs.id
    }
    
    let id = UUID()
    var name: String
    var icon: String
    var coordinate: CLLocationCoordinate2D
    var eventId: String // NostrEventId
    var event: NostrEvent?
    var channel: Channel?
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    
    @Published var marks: [Mark] = []
    
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
    
    func clearMarks() {
        self.marks = []
    }
}

extension Notification.Name {
    static let goToLandmark = Notification.Name("goToLandmark")
    static let goToCoordinate = Notification.Name("goToCoordinate")
    static let joinChat = Notification.Name("joinChat")
}

struct SkateView: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var room: Lobby
    @EnvironmentObject var viewModel: ContentViewModel
    
    @ObservedObject var navigation = NavigationManager.shared

    @Query private var spots: [Spot]
    
    @StateObject var locationManager = LocationManager()
    
    @State private var showingAlert = false
    @State private var isShowingLeadOptions = false
    
    @State private var npub: String?
    @State var channelId = ""
    
    func handleLongPress(lead: Lead) {
        print("Long press detected on lead: \(lead.name)")
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
                        ForEach(Array(room.leads.values)) { lead in
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
                                            channelId = lead.eventId
                                            navigation.isShowingChannelFeed.toggle()
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
                            print("Tapped at \(coordinate)")
                            locationManager.marks = []
                            
                            addMarker(at: coordinate)
                        }
                    }
                }
                
                HStack(spacing: 20) {
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
            .fullScreenCover(isPresented: $navigation.isShowingChannelFeed) {
                if self.channelId.isEmpty {
                    Text("No lead available at this index.")
                } else {
                    let lead = room.leads[self.channelId] ??
                        Lead(name: "Private Group Chat",
                             icon: "💬",
                             coordinate: AppData().landmarks[0].locationCoordinate,
                             eventId: self.channelId,
                             event: nil,
                             channel: nil)
                    
                    NavigationView {
                        ChannelFeed(lead: lead)
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
            .onReceive(NotificationCenter.default.publisher(for: .goToLandmark)) { _ in
                if  let locationCoordinate = navigation.landmark?.locationCoordinate {
                    locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToCoordinate)) { _ in
                if  let locationCoordinate = navigation.coordinates {
                    locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .joinChat)) { notification in
                if  let locationCoordinate = navigation.coordinates {
                    locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                }
                
                // Join Chain
                navigation.isShowingChannelFeed = true
                
                if let channelId = notification.userInfo?["channelId"] as? String {
                    print("Joined chat with channel ID: \(channelId)")
                        
                    self.channelId = channelId
                }
            }
            .onReceive(viewModel.$observedSpot) { observedSpot in
                DispatchQueue.main.async {
                    if let spot = observedSpot.spot {
                        context.insert(spot)
                        viewModel.observedSpot.spot = nil
                        locationManager.clearMarks()
                    }
                }
            }
        }
    }
    
    func addMarker(at coordinate: CLLocationCoordinate2D) {
        let mark = Mark(name: "Marker \(spots.count + 1)", coordinate: coordinate)
        locationManager.marks.append(mark)
        
        let nearbyLandmarks = getNearbyLandmarks(for: coordinate)
        if !nearbyLandmarks.isEmpty {
            print("Nearby landmarks: \(nearbyLandmarks.map { $0.name })")
            
            let spot = nearbyLandmarks[0]
            npub = spot.npub
            
            navigation.isShowingMarkerOptions = true
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
