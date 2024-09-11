//
//  SkateView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import SwiftData
import MapKit

struct Mark: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct Lead: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

final class SkateViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    
    @Published var marks: [Mark] = []
    @Published var leads: [Lead] = [Lead(name: "Cleaning Job", coordinate: SkatePayData().landmarks[0].locationCoordinate)]
    
    @Published var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: SkatePayData().landmarks[0].locationCoordinate.latitude, longitude: SkatePayData().landmarks[0].locationCoordinate.longitude), latitudinalMeters: 64, longitudinalMeters: 64)
    
    @Published var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: SkatePayData().landmarks[0].locationCoordinate.latitude, longitude: SkatePayData().landmarks[0].locationCoordinate.longitude), latitudinalMeters: 64, longitudinalMeters: 64)
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
}

extension Notification.Name {
    static let didDismissToContentView = Notification.Name("didDismissToContentView")
}
class NavigationManager: ObservableObject {
    @Published var path = NavigationPath()
    @Published var landmark: Landmark?
 
    func dismissToContentView() {
        path = NavigationPath()
        NotificationCenter.default.post(name: .didDismissToContentView, object: nil)
    }
}

struct SkateView: View {
    @StateObject private var navManager = NavigationManager()

    @Query private var spots: [Spot]

    @StateObject var viewModel = SkateViewModel()
    
    @State private var showingAlert = false
    
    @State private var npub: String?
    @State private var isShowingSheet = false
    
    @State private var longPressActive: [String: Bool] = [:]
    @State var leads: [Lead] = [Lead(name: "Cleaning Job", coordinate: SkatePayData().landmarks[0].locationCoordinate)]
    
    @State private var showDirectory = false

    func handleLongPress(lead: Lead) {
        print("Long press detected on lead: \(lead.name)")
        // Add your logic here for what should happen when a lead is long-pressed
        // For example, show a sheet with more details, start a chat, etc.
    }
    
    func binding(for key: String) -> Binding<Bool> {
        return Binding<Bool>(
            get: { longPressActive[key] ?? false },
            set: { longPressActive[key] = $0 }
        )
    }
    
    init() {
        self.leads.forEach { lead in
            self.longPressActive[lead.name] = false
        }
    }
    
    var body: some View {
        NavigationStack(path: $navManager.path) {
            VStack {
                MapReader { proxy in
                    Map(position: $viewModel.mapPosition) {
                        //                    UserAnnotation()
                        // Marks
                        ForEach(viewModel.marks) { mark in
                            Marker(mark.name, coordinate: mark.coordinate)
                                .tint(.orange)
                        }
                        //                    // Leads
                        //                    ForEach(leads) { lead in
                        //                        if let name = lead.name {
                        //                            LeadAnnotationView(lead: lead, isPressed: binding(for: lead.name))
                        //                        }
                        //                    }
                    }
                    .onAppear{
                        viewModel.checkIfLocationIsEnabled()
                    }
                    .onTapGesture { position in
                        if let coordinate = proxy.convert(position, from: .local) {
                            print("Tapped at \(coordinate)")
                            viewModel.marks = []
                            
                            addMarker(at: coordinate)
                        }
                    }
                }
                
                HStack {
                    Button("Directory") {
                        navManager.path.append("LandmarkDirectory")
                    }
                    .padding(32)
                    .alert("Spot marked.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) { }
                    }
                    
                    Button("Clear mark") {
                        viewModel.marks = []
                    }
                    .padding(32)
                    .alert("Spot marked.", isPresented: $showingAlert) {
                        Button("Ok", role: .cancel) { }
                    }
                }
            }
            .sheet(isPresented: $isShowingSheet) {
                MarkerOptions(npub: npub, marks: viewModel.marks)
            }
            .navigationDestination(for: String.self) { route in
                if route == "LandmarkDirectory" {
                    LandmarkDirectory(navManager: navManager)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didDismissToContentView)) { _ in
                if  let locationCoordinate = navManager.landmark?.locationCoordinate {                    
                    viewModel.updateMapRegion(with: CLLocationCoordinate2D(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude))
                }
             }
        }
    }
    
    func addMarker(at coordinate: CLLocationCoordinate2D) {
        let mark = Mark(name: "Marker \(spots.count + 1)", coordinate: coordinate)
        viewModel.marks.append(mark)
        
        let nearbyLandmarks = getNearbyLandmarks(for: coordinate)
        if !nearbyLandmarks.isEmpty {
            print("Nearby landmarks: \(nearbyLandmarks.map { $0.name })")
            
            let spot = nearbyLandmarks[0]
            npub = spot.npub
            
            isShowingSheet = true
        } else {
            print("No nearby landmarks")
        }
    }
    
    func getNearbyLandmarks(for coordinate: CLLocationCoordinate2D) -> [Landmark] {
        let markerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let landmarks = SkatePayData().landmarks
        
        return landmarks.filter { landmark in
            let landmarkLocation = CLLocation(latitude: landmark.locationCoordinate.latitude, longitude: landmark.locationCoordinate.longitude)
            let distance = markerLocation.distance(from: landmarkLocation)
            
            return distance <= 32
        }
    }
    
    func convertPointToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D? {
        let mapView = MKMapView(frame: .zero)
        mapView.setRegion(viewModel.mapRegion, animated: false)
        
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        return coordinate
    }
}

#Preview {
    SkateView().environment(SkatePayData())
}
