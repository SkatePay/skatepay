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

struct ChannelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
        
    @StateObject private var feedDelegate = FeedDelegate()
    
    @State var channelId: String
    @State var leadType = LeadType.outbound
    
    @State private var isShowingToolBoxView = false
    
    @State private var keyboardHeight: CGFloat = 0
    
    @State private var showingConfirmationAlert = false
    @State private var selectedChannelId: String? = nil
    @State private var videoURL: URL?
    
    @State private var showMediaActionSheet = false
    @State private var selectedMediaURL: URL?
    
    @State private var isInitialized = false // THis value prevents resetting the scroll when navigating to other views
    
    var landmarks: [Landmark] = AppData().landmarks
    
    let keychainForNostr = NostrKeychainStorage()

    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
    }
    
    var body: some View {
        VStack {
            ChatView(
                currentUser: getCurrentUser(),
                messages: $feedDelegate.messages,
                shouldScrollToBottom: $network.shouldScrollToBottom,
                onTapAvatar: { senderId in
                    navigation.path.append(NavigationPathType.userDetail(npub: senderId))
                },
                onTapVideo: { message in
                    if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
                        let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
                        self.selectedMediaURL = URL(string: videoURLString)
                        showMediaActionSheet.toggle()
                    }
                },
                onTapLink: { channelId in
                    selectedChannelId = channelId
                    showingConfirmationAlert = true
                },
                onSend: { text in
                    network.publishChannelEvent(channelId: channelId, content: text)
                }
            )
            .onAppear {
                self.setupSubscription()
            }
            .onAppear(perform: observeNotification)
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .navigationBarBackButtonHidden()
            .actionSheet(isPresented: $showMediaActionSheet) {
                createMediaActionSheet(for: selectedMediaURL)
            }
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                if let lead = self.feedDelegate.lead {
                    EditChannel(lead: lead, channel: lead.channel)
                        .environmentObject(navigation)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            self.isShowingToolBoxView.toggle()
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            navigation.path.append(NavigationPathType.camera)
                        }) {
                            Image(systemName: "camera.on.rectangle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .alert(isPresented: $showingConfirmationAlert) {
                Alert(
                    title: Text("Confirmation"),
                    message: Text("Are you sure you want to join this channel?"),
                    primaryButton: .default(Text("Yes")) {
                        openChannelInvite()
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
            .onReceive(NotificationCenter.default.publisher(for: .uploadImage)) { notification in
                if let assetURL = notification.userInfo?["assetURL"] as? String {
                    network.publishChannelEvent(channelId: channelId,
                                                kind: .photo,
                                                content: assetURL
                    )
                }
            }
            .padding(.bottom, keyboardHeight)
            .modifier(IgnoresSafeArea())
        }
    }
    
    // MARK: Blacklist
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    private func openChannelInvite() {
        guard let channelId = selectedChannelId else { return }

        navigation.joinChannel(channelId: channelId)
    }
    
    // Function to create the ActionSheet for Play, Download, and Share
    private func createMediaActionSheet(for url: URL?) -> ActionSheet {
        return ActionSheet(
            title: Text("Media Options"),
            message: Text("Choose an action for the media."),
            buttons: [
                .default(Text("Play")) {
                    if let videoURL = url {
                        navigation.path.append(NavigationPathType.videoPlayer(url: videoURL))
                    }
                },
                .default(Text("Download")) {
                    if let videoURL = url {
                        downloadVideo(from: videoURL)
                    }
                },
                .default(Text("Share")) {
                    if let videoURL = url {
                        shareVideo(videoURL)
                    }
                },
                .cancel()
            ]
        )
    }
    
    private func downloadVideo(from url: URL) {
        print("Downloading video from \(url)")
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

private extension ChannelView {
    private func setupSubscription() {
        if !isInitialized {
            navigation.channelId = channelId
            network.leadType = leadType
            
            feedDelegate.setDataManager(dataManager: dataManager)
            feedDelegate.setNavigation(navigation: navigation)
            feedDelegate.setNetwork(network: network)
                                
            feedDelegate.subscribeToChannelWithId(_channelId: channelId)
            
            self.isInitialized = true
        }
    }
}

#Preview {
    ChannelView(channelId: "")
}

