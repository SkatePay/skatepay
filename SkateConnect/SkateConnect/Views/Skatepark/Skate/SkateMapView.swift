//
//  SkateMapView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/26/25.
//

import Combine
import ConnectFramework
import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct SkateMapView: View {
    @Environment(\.modelContext) private var context

    @EnvironmentObject private var channelViewManager: ChannelViewManager
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var lobby: Lobby
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var stateManager: StateManager
    
    @State private var showMenu = false
    @State private var selectedLead: Lead? = nil
    
    @Query private var spots: [Spot]
    
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        MapReader { proxy in
            Map(position: $locationManager.mapPosition) {
                UserAnnotation()
                
                if let coordinate = locationManager.pinCoordinate {
                    Annotation("❌", coordinate: coordinate) {}
                }
                
                // Marks
                ForEach(stateManager.marks) { mark in
                    Marker(mark.name, coordinate: mark.coordinate)
                        .tint(.orange)
                }
                
                // Leads
                ForEach(lobby.leads) { lead in
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
                                    feedbackGenerator.impactOccurred()
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
                locationManager.updateMapRegionOnUserInteraction(region: context.region)
            }
            .onAppear {
                locationManager.checkIfLocationIsEnabled()
            }
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    stateManager.marks = []
                    stateManager.addMarker(at: coordinate, spots: spots)
                    
                    locationManager.updateMapRegion(with: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
        }
    }
    
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
                    // Handle camera action
                    navigation.isShowingCameraView = true
                    navigation.channelId = lead.channelId
                },
                .default(Text("Copy Link")) {
                    let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/channel/\(lead.channelId)"
                    UIPasteboard.general.string = customUrlString
                    
                    stateManager.isLinkCopied = true
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
                    
                    stateManager.isInviteCopied = true
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
}
