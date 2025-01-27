//
//  ChannelView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import ConnectFramework
import CryptoKit
import Foundation
import MessageKit
import NostrSDK
import Combine
import CoreLocation
import SwiftData
import SwiftUI
import UIKit

// MARK: - Feed Delegate

struct ContentStructure: Codable {
    let content: String
    let kind: Kind
}

enum Kind: String, Codable {
    case video
    case photo
    case message
    case subscriber
}

class SelectedUserManager: ObservableObject {
    @Published var npub: String = ""
}

enum LeadType: String {
    case outbound = "outbound"
    case inbound = "inbound"
}

struct ChannelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    @Query(sort: \Spot.channelId) private var spots: [Spot]
        
    @StateObject private var feedDelegate = FeedDelegate()
    
    @State var channelId: String
    @State private var isShowingToolBoxView = false
    
    @State private var keyboardHeight: CGFloat = 0
    
    @State private var isShowingUserDetail = false
    
    @State private var showingConfirmationAlert = false
    @State private var selectedChannelId: String? = nil
    @State private var videoURL: URL?
    
    @State private var showMediaActionSheet = false
    @State private var selectedMediaURL: URL?
    
    var landmarks: [Landmark] = AppData().landmarks
    
    var body: some View {
        VStack {
            ChatAreaView(
                messages: $feedDelegate.messages,
                onTapAvatar: { senderId in
                    navigation.selectedUserNpub = senderId
                    navigation.isShowingUserDetail.toggle()
                },
                onTapVideo: { message in
                    if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
                        let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
                        
                        //                        self.videoURL = URL(string: videoURLString)
                        //                        navigation.isShowingVideoPlayer.toggle()
                        
                        self.selectedMediaURL = URL(string: videoURLString)
                        showMediaActionSheet.toggle() // Trigger the action sheet
                    }
                },
                onTapLink: { channelId in
                    selectedChannelId = channelId
                    showingConfirmationAlert = true
                },
                onSend: { text in
                    navigation.channelId = channelId
                    feedDelegate.publishDraft(text: text)
                }
            )
            .onAppear {
                feedDelegate.setDataManager(dataManager: dataManager)
                feedDelegate.setNavigation(navigation: navigation)
                feedDelegate.setNetwork(network: network)
                
                navigation.channelId = channelId
                self.setup()
            }
            .actionSheet(isPresented: $showMediaActionSheet) {
                createMediaActionSheet(for: selectedMediaURL)
            }
            .onAppear(perform: observeNotification)
            .onDisappear {
                self.feedDelegate.cleanUp()
                NotificationCenter.default.removeObserver(self)
            }
            .navigationBarBackButtonHidden()
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                if let lead = self.feedDelegate.lead {
                    EditChannel(lead: lead, channel: lead.channel)
                        .environmentObject(navigation)
                }
            }
            .navigationBarItems(
                leading:
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                        }
                        
                        Button(action: {
                            navigation.isShowingEditChannel.toggle()
                        }) {
                            if let lead = self.feedDelegate.lead {
                                if let landmark = findLandmark(lead.channelId) {
                                    HStack {
                                        landmark.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 35, height: 35)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("\(landmark.name)")
                                                .fontWeight(.semibold)
                                                .font(.headline)
                                        }
                                    }
                                } else {
                                    if let channel = lead.channel {
                                        Text("\(channel.name)")
                                            .fontWeight(.semibold)
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    },
                trailing:
                    HStack(spacing: 16) {
                        Button(action: {
                            self.isShowingToolBoxView.toggle()
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            navigation.isShowingCameraView = true
                        }) {
                            Image(systemName: "camera.on.rectangle.fill")
                                .foregroundColor(.blue)
                        }
                    }
            )
        }
        .alert(isPresented: $showingConfirmationAlert) {
            Alert(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to join this channel?"),
                primaryButton: .default(Text("Yes")) {
                    openInvite()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $isShowingToolBoxView) {
            ToolBoxView()
                .environmentObject(navigation)
                .presentationDetents([.medium])
                .onAppear {
                    navigation.channelId = channelId
                }
        }
        .fullScreenCover(isPresented: $navigation.isShowingCameraView) {
            NavigationView {
                CameraView()
                    .environmentObject(navigation)
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingVideoPlayer) {
            if let videoURL = videoURL {
                NavigationView {
                    VideoPreviewView(url: videoURL)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .uploadImage)) { notification in
            if let assetURL = notification.userInfo?["assetURL"] as? String {
                feedDelegate.publishDraft(text: assetURL, kind: .photo)
            }
        }
        .padding(.bottom, keyboardHeight)
        .modifier(IgnoresSafeArea()) //fixes issue with IBAV placement when keyboard appear
    }
    
    // MARK: Blacklist
    func getBlacklist() -> [String] {
        return foes.map({$0.npub})
    }
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    private func openInvite() {
        guard let channelId = selectedChannelId else { return }
        
        if let spot = dataManager.findSpotForChannelId(channelId) {
            navigation.coordinate = spot.locationCoordinate
        }
        
        self.channelId = channelId
        setup(leadType: .inbound)
    }
    
    // Function to create the ActionSheet for Play, Download, and Share
    private func createMediaActionSheet(for url: URL?) -> ActionSheet {
        return ActionSheet(
            title: Text("Media Options"),
            message: Text("Choose an action for the media."),
            buttons: [
                .default(Text("Play")) {
                    if let videoURL = url {
                        self.videoURL = videoURL
                        navigation.isShowingVideoPlayer.toggle() // Play the video
                    }
                },
                .default(Text("Download")) {
                    if let videoURL = url {
                        downloadVideo(from: videoURL) // Handle downloading the video
                    }
                },
                .default(Text("Share")) {
                    if let videoURL = url {
                        shareVideo(videoURL) // Handle sharing the video
                    }
                },
                .cancel()
            ]
        )
    }
    
    // Function to handle video download
    private func downloadVideo(from url: URL) {
        // Implementation for downloading the video
        print("Downloading video from \(url)")
        // Add your video download logic here
    }
    
    func setup(leadType: LeadType = .outbound) {
        navigation.channelId = channelId
        self.feedDelegate.subscribeToChannelWithId(_channelId: channelId, leadType: leadType)
    }
    
    private func observeNotification() {
        NotificationCenter.default.addObserver(
            forName: .muteUser,
            object: nil,
            queue: .main
        ) { _ in
            self.feedDelegate.subscribeToChannelWithId(_channelId: self.channelId)
        }
    }
}

struct IgnoresSafeArea: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 14.0, *) {
            content.ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            content
        }
    }
}
#Preview {
    ChannelView(channelId: "")
}
