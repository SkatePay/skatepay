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
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    
    @State private var showMenu = false
    @State private var selectedLead: Lead? = nil
    @State private var highlightedLead: Lead? = nil

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
                        let color = lead == highlightedLead ? Color.green : lead.color
                        
                        ZStack {
//                            Circle()
//                                .foregroundStyle(color.opacity(0.5))
//                                .frame(width: 80, height: 80)
                            
                            Text(lead.icon)
                                .font(.system(size: 24))
                                .symbolEffect(.variableColor)
                                .padding()
                                .foregroundStyle(.white)
                                .background(color)
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
                    }
                }
            }
            .mapStyle(
                .standard(
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .onMapCameraChange(frequency: .continuous) { context in
                locationManager.updateMapRegionOnUserInteraction(region: context.region)
            }
            .onAppear {
                locationManager.checkIfLocationIsEnabled()
            }
            .onTapGesture { position in
                handleMapTap(position: position, proxy: proxy)
            }
            .actionSheet(isPresented: $showMenu) {
                if let lead = selectedLead {
                    return createActionSheetForLead(lead)
                } else {
                    return ActionSheet(title: Text("Error"), message: Text("No lead selected."), buttons: [.cancel()])
                }
            }
        }
    }
    
    func createActionSheetForLead(_ lead: Lead) -> ActionSheet {
        let spot = dataManager.findSpotsForChannelId(lead.channelId).first
                
        var canBeRemoved = true
        
        if let spot = spot, let note = spot.note.split(separator: ":").last.map(String.init) {
            if note == "public" {
                canBeRemoved = false
            }
        }
        
        var buttons: [ActionSheet.Button] = [
            .default(Text("Open")) {
                locationManager.panMapToCachedCoordinate(lead.coordinate)
                channelViewManager.openChannel(channelId: lead.channelId, invite: lead.note.contains("invite"))
            },
            .default(Text("Camera")) {
                navigation.channelId = lead.channelId
                navigation.path.append(NavigationPathType.camera)
            }
        ]
        
        if let channel = network.getChannel(for: lead.channelId) {
            if let creationEvent = channel.creationEvent {
                if ["invite", "public"].allSatisfy({ !lead.note.contains($0) }),
                   dataManager.isMe(pubkey: creationEvent.pubkey) {
                    buttons.append(.default(Text("Move")) {
                        highlightedLead = lead
                    })
                }
            }

            buttons.append(.default(Text("Copy invite")) {
                var inviteString = lead.channelId

                if let encryptedString = MessageHelper.encryptChannelInviteToString(channel: channel) {
                    inviteString = encryptedString
                }
//                }
                UIPasteboard.general.string = "channel_invite:\(inviteString)"
                stateManager.isInviteCopied = true
            })
        }

        buttons.append(.default(Text("See on the Web")) {
            MainHelper.shareChannel(lead.channelId)
        })
        
        buttons.append(.default(Text("Open in Maps")) {
            let coordinate = lead.coordinate
            let locationString = "\(coordinate.latitude),\(coordinate.longitude)"
            if let url = URL(string: "http://maps.apple.com/?daddr=\(locationString)&dirflg=d"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        })

        if canBeRemoved {
            buttons.append(.destructive(Text("Remove")) {
                channelViewManager.deleteChannelWithId(lead.channelId)
                dataManager.removeSpotForChannelId(lead.channelId)
            })
        }

        buttons.append(.cancel())

        return ActionSheet(
            title: Text(lead.name),
            message: Text("Choose an action for this spot."),
            buttons: buttons
        )
    }
}

private extension SkateMapView {
    func handleMapTap(position: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(position, from: .local) else { return }
        stateManager.marks = []
        
        if (highlightedLead == nil) {
            stateManager.addMarker(at: coordinate, spots: spots)
        } else {
            saveLocationChange(location: coordinate)
        }
    }
    
    func saveLocationChange(location: CLLocationCoordinate2D) {
        guard let channelId = highlightedLead?.channelId else {
            print("Missing channelId")
            return
        }
        
        guard var channel = network.getChannel(for: channelId) else {
            print("Missing channel")
            return
        }
        
        guard let aboutDecoded = channel.aboutDecoded else {
            print("Missing aboutDecoded")
            return
        }
        
        let aboutStructure = AboutStructure(
            description: aboutDecoded.description,
            location: location,
            note: aboutDecoded.note
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let aboutData = try? encoder.encode(aboutStructure),
              let aboutJSONString = String(data: aboutData, encoding: .utf8) else {
            print("Encoding aboutStructure failed")
            return
        }
        
        let metadata = ChannelMetadata(
            name: channel.metadata?.name ?? channel.name,
            about: aboutJSONString,
            picture: channel.metadata?.picture ?? channel.picture,
            relays: channel.metadata?.relays ?? channel.relays
        )
        
        channel.metadata = metadata
        
        NotificationCenter.default.post(
            name: .saveChannelMetadata,
            object: nil,
            userInfo: [
                "channel": channel
            ]
        )
        
        highlightedLead = nil
    }
}
