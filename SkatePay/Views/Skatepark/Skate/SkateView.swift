//
//  SkateView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
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
    
    var binding: Binding<MKCoordinateRegion> {
        Binding {
            self.mapRegion
        } set: { newRegion in
            self.mapRegion = newRegion
        }
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
                mapRegion = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
            }
            
        default:
            break
        }
    }
}

struct ChatOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var npub: String?
    
    @State private var showChatView = false
    
    var landmarks: [Landmark] = SkatePayData().landmarks
    
    func getLandmark() -> Landmark? {
        return landmarks.first { $0.npub == npub }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Chat Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                print("Joining park chat")
                showChatView = true
            }) {
                Text("Join Active Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                print("Starting new chat")
                dismiss()
            }) {
                Text("Start New Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                print("Adding spot to bookmarks")
                dismiss()
            }) {
                Text("Add to Address Book")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .fullScreenCover(isPresented: $showChatView) {
            let landmark = getLandmark()
            NavigationView {
                SpotFeed(npub: npub ?? "")
                    .navigationBarTitle("\(npub ?? "")")
                    .navigationBarItems(leading:
                                            Button(action: {
                        showChatView = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            
                            if let image = landmark?.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())
                            }
                            if let name = landmark?.name {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(name)
                                        .fontWeight(.semibold)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                }
                            }
                            Spacer()
                        }
                    }
                    )
            }
        }
        .padding()
    }
}

struct SkateView: View {
    @StateObject var viewModel = SkateViewModel()
    
    @State private var showingAlert = false
    
    @State private var npub: String?
    @State private var isShowingSheet = false
    
    @State private var longPressActive: [String: Bool] = [:]
    @State var leads: [Lead] = [Lead(name: "Cleaning Job", coordinate: SkatePayData().landmarks[0].locationCoordinate)]

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
        VStack {
            MapReader { proxy in
                Map(initialPosition: .region(viewModel.mapRegion)) {
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
            
            Button("Clear Spots") {
                viewModel.marks = []
            }
            .padding(32)
            .alert("Spot marked.", isPresented: $showingAlert) {
                Button("Ok", role: .cancel) { }
            }
        }
        .sheet(isPresented: $isShowingSheet) {
            ChatOptionsView(npub: $npub)
        }
    }
    
    func addMarker(at coordinate: CLLocationCoordinate2D) {
        let mark = Mark(name: "Marker \(viewModel.marks.count + 1)", coordinate: coordinate)
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
