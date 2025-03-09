//
//  ChannelView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import os
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
    let log = OSLog(subsystem: "SkateConnect", category: "ChannelVIew")

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var eventBus: EventBus
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
            
    @StateObject private var eventPublisher = ChannelEventPublisher()
    
    @StateObject private var eventListenerForMessages = ChannelMessageListener()
    @StateObject private var eventListenerForMetadata = ChannelMetadataListener()

    // Credentials
    let keychainForNostr = NostrKeychainStorage()

    @State var channelId: String
    @State var leadType = LeadType.outbound
    
    // Sheets
    @State private var isShowingToolBoxView = false
    @State private var showingConfirmationAlert = false
    
    @State private var selectedChannelId: String? = nil
    @State private var videoURL: URL?
    
    @State private var showMediaActionSheet = false
    @State private var selectedMediaURL: URL?
    
    @State private var keyboardHeight: CGFloat = 0

    @State private var shouldScrollToBottom = true

    var landmarks: [Landmark] = AppData().landmarks
    
    var body: some View {
        VStack {
            ChatView(
                currentUser: getCurrentUser(),
                messages: $eventListenerForMessages.messages,
                shouldScrollToBottom: $shouldScrollToBottom,
                onTapAvatar: { senderId in
                    navigation.path.append(NavigationPathType.userDetail(npub: senderId))
                    shouldScrollToBottom = false
                },
                onTapVideo: { message in
                    if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
                        let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
                        self.selectedMediaURL = URL(string: videoURLString)
                        showMediaActionSheet.toggle()
                    }
                    shouldScrollToBottom = false
                },
                onTapLink: { channelId in
                    selectedChannelId = channelId
                    showingConfirmationAlert = true
                    
                    shouldScrollToBottom = false
                },
                onSend: { text in
                    network.publishChannelEvent(channelId: channelId, content: text)
                    shouldScrollToBottom = true
                }
            )
            .onAppear {
                if let account = keychainForNostr.account {
                    self.eventListenerForMetadata.setChannelId(channelId)
                    self.eventListenerForMetadata.reset()
                    
                    self.eventPublisher.subscribeToMetadataFor(channelId)

                    if (self.eventListenerForMessages.receivedEOSE) {
                        shouldScrollToBottom = false
                        return
                    }
                    
                    shouldScrollToBottom = true

                    self.eventListenerForMessages.setChannelId(channelId)
                    self.eventListenerForMessages.setDependencies(dataManager: dataManager, account: account)
                    self.eventListenerForMessages.reset()

                    self.eventPublisher.subscribeToMessagesFor(channelId)
                }
            }
            .navigationBarBackButtonHidden()
            .actionSheet(isPresented: $showMediaActionSheet) {
                createMediaActionSheet(for: selectedMediaURL)
            }
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                if let lead = self.eventListenerForMetadata.metadata {
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
                            if let lead = self.eventListenerForMetadata.metadata {
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
            .onReceive(NotificationCenter.default.publisher(for: .muteUser)) { _ in
                if let account = keychainForNostr.account {
                    self.eventListenerForMetadata.setChannelId(channelId)
                    
                    self.eventPublisher.subscribeToMetadataFor(channelId) 

                    self.eventListenerForMessages.setChannelId(channelId)
                    self.eventListenerForMessages.setDependencies(dataManager: dataManager, account: account)
                    self.eventListenerForMessages.reset()
                    
                    self.eventPublisher.subscribeToMessagesFor(channelId)
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
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
}

// MARK: - Helpers
private extension ChannelView {
    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
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

