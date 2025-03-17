//
//  DMView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import os
import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import SwiftUI
import UIKit

struct DMView: View, LegacyDirectMessageEncrypting, EventCreating {
    let log = OSLog(subsystem: "SkateConnect", category: "DirectMessageView")

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var eventBus: EventBus
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    
    @StateObject private var eventPublisher = DMEventPublisher()
    
    @StateObject private var eventListenerForMessages = DMMessageListener()

    // Credentials
    private let keychainForNostr = NostrKeychainStorage()

    private var user: User
    private var message: String

    // Sheets
    @State private var isShowingCameraView = false
    @State private var isShowingVideoPlayer = false
    
    @State private var showingConfirmationAlert = false
    @State private var showAlertForReporting = false
    @State private var showAlertForAddingPark = false
    
    // Action State
    @State private var selectedChannelId: String?
    @State private var selectedInviteString: String? = nil
    @State private var videoURL: URL?
    
    // View State
    @State private var shouldScrollToBottom = true

    init(user: User, message: String = "") {
        self.user = user
        self.message = message
    }
    
    var body: some View {
        ChatView(
            currentUser: getCurrentUser(),
            messages: $eventListenerForMessages.messages,
            shouldScrollToBottom: $shouldScrollToBottom,
            onTapAvatar: {_ in 
                print("Avatar tapped")
                shouldScrollToBottom = false
            },
            onTapVideo: handleVideoTap,
            onTapLink: { action, channelId, inviteString in
                selectedChannelId = channelId
                selectedInviteString = inviteString

                showingConfirmationAlert = true
                shouldScrollToBottom = false
            },
            onSend: { text in
                guard let publicKey = PublicKey(npub: user.npub) else { return }
                network.publishDMEvent(pubKey: publicKey, content: text)
                shouldScrollToBottom = true
            }
        )
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: backButton, trailing: actionButtons)
        .actionSheet(isPresented: $showingConfirmationAlert) {
            ActionSheet(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to join this channel?"),
                buttons: [
                    .default(Text("Yes")) {
                        openChannelInvite()
                    },
                    .default(Text("Copy Invite")) {
                        
                        showingConfirmationAlert = false
                        
                        if let inviteString = selectedInviteString {
                            UIPasteboard.general.string = "channel_invite:\(inviteString)"
                        } else {
                            UIPasteboard.general.string = "channel_invite:NOT_AVAILABLE"
                        }
                    },
                    .cancel(Text("Maybe Later")) {
                        showingConfirmationAlert = false
                    }
                ]
            )
        }
        .onChange(of: eventListenerForMessages.receivedEOSE) {
            if eventListenerForMessages.receivedEOSE {
                shouldScrollToBottom = true
            }
        }
        .onChange(of: eventListenerForMessages.timestamp) {
            if eventListenerForMessages.receivedEOSE {
                shouldScrollToBottom = true
            }
        }
        .onAppear {
            if (self.eventListenerForMessages.receivedEOSE) {
                return
            }
            
            shouldScrollToBottom = true
            
            if let account = keychainForNostr.account {
                
                guard let publicKey = PublicKey(npub: user.npub) else {
                    os_log("🔥 can't convert npub", log: log, type: .error)
                    return
                }
                
                self.eventListenerForMessages.setPublicKey(publicKey)
                
                self.eventListenerForMessages.setDependencies(
                    dataManager: dataManager,
                    debugManager: debugManager,
                    account: account
                )
                
                self.eventListenerForMessages.reset()
                
                self.eventPublisher.subscribeToUserWithPublicKey(publicKey)
            }
        }
        .modifier(IgnoresSafeArea())
    }
}

// MARK: - Helpers
private extension DMView {
    private var connected: Bool {
        network.relayPool?.relays.contains { $0.url == URL(string: user.relayUrl) } ?? false
    }

    func formatName() -> String {
        dataManager.findFriend(user.npub)?.name ?? MainHelper.friendlyKey(npub: user.npub)
    }
    
    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
    }
}

// MARK: - UI
private extension DMView {
    private var backButton: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.left")
            }
            Button(action: {}) {
                HStack {
                    Image("user-skatepay")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatName()).fontWeight(.semibold).font(.headline)
                        Text(connected ? "online" : "offline").font(.footnote).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {}) {
                Image(systemName: "network").foregroundColor(.blue)
            }
            Button(action: { isShowingCameraView = true }) {
                Image(systemName: "camera.on.rectangle.fill").foregroundColor(.blue)
            }
        }
    }

    private func openChannelInvite() {
        guard let channelId = selectedChannelId else { return }

        navigation.joinChannel(channelId: channelId)
    }

    private func handleVideoTap(message: MessageType) {
        if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
            let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
            videoURL = URL(string: videoURLString)
            isShowingVideoPlayer.toggle()
        }
        
        shouldScrollToBottom = false
    }
}
#Preview {
    DMView(user: AppData().users[0])
}
