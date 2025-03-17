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
    @EnvironmentObject var stateManager: StateManager
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var walletManager: WalletManager
    
    @StateObject private var eventPublisher = ChannelEventPublisher()
    
    @StateObject private var eventListenerForMessages = ChannelMessageListener()
    @StateObject private var eventListenerForMetadata = ChannelMetadataListener()

    // Credentials
    let keychainForNostr = NostrKeychainStorage()

    @State var channelId: String
    @State var type = ChannelType.outbound
    
    // Sheets
    @State private var isShowingToolBoxView = false
    
    @State private var showingMediaActionSheet = false
    @State private var showingInviteActionSheet = false
    @State private var showingInvoiceActionSheet = false
    
    // Action State
    @State private var selectedChannelId: String? = nil
    @State private var selectedMediaURL: URL?
    @State private var selectedInviteString: String? = nil
    @State private var selectedInvoiceString: String? = nil
    @State private var selectedInvoice: Invoice? = nil

    // View State
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
                        showingMediaActionSheet = true
                    }
                    shouldScrollToBottom = false
                },
                onTapLink: { action, channelId, dataString in
                    if action == .invite {
                        selectedInviteString = dataString
                        showingInviteActionSheet = true
                    }
                    
                    if action == .invoice {
                        setSelectedInvoiceString(dataString)
                        showingInvoiceActionSheet = true
                    }
                    
                    selectedChannelId = channelId
                    shouldScrollToBottom = false
                },
                onSend: { text in
                    network.publishChannelEvent(channelId: channelId, content: text)
                    shouldScrollToBottom = true
                }
            )
            .navigationBarBackButtonHidden()
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                if let channel = self.eventListenerForMetadata.channel {
                    EditChannel(channel: channel)
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
                            if let channel = eventListenerForMetadata.channel {
                                if let channelId = channel.creationEvent?.id,
                                   let landmark = findLandmark(channelId) {
                                    
                                    HStack {
                                        landmark.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 35, height: 35)
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(landmark.name)
                                                .fontWeight(.semibold)
                                                .font(.headline)
                                        }
                                    }
                                    
                                } else {
                                    Text(channel.name)
                                        .fontWeight(.semibold)
                                        .font(.headline)
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
                            Image(systemName: "menucard.fill")
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
            .sheet(isPresented: $isShowingToolBoxView) {
                ToolBoxView()
                    .environmentObject(debugManager)
                    .environmentObject(navigation)
                    .environmentObject(uploadManager)
                    .environmentObject(walletManager)
                    .presentationDetents([.medium])
                    .onAppear {
                        navigation.channelId = channelId
                    }
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
                if let account = keychainForNostr.account {
                    self.eventListenerForMetadata.setChannelType(type)
                    self.eventListenerForMetadata.setChannelId(channelId)
                    self.eventListenerForMetadata.reset()
                    
                    self.eventPublisher.subscribeToMetadataFor(channelId)

                    if (self.eventListenerForMessages.receivedEOSE) {
                        shouldScrollToBottom = false
                        return
                    }
                    
                    shouldScrollToBottom = true

                    self.eventListenerForMessages.setChannelId(channelId)
                    self.eventListenerForMessages.setDependencies(
                        dataManager: dataManager,
                        debugManager: debugManager,
                        account: account
                    )
                    self.eventListenerForMessages.reset()

                    self.eventPublisher.subscribeToMessagesFor(channelId)
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
                    self.eventListenerForMessages.setDependencies(
                        dataManager: dataManager,
                        debugManager: debugManager,
                        account: account
                    )
                    self.eventListenerForMessages.reset()
                    
                    self.eventPublisher.subscribeToMessagesFor(channelId)
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .modifier(IgnoresSafeArea())
        }
        .confirmationDialog("Media Options", isPresented: $showingMediaActionSheet, titleVisibility: .visible) {
            Button("Play") {
                if let videoURL = selectedMediaURL {
                    navigation.path.append(NavigationPathType.videoPlayer(url: videoURL))
                }
            }
            Button("Download") {
                if let videoURL = selectedMediaURL {
                    downloadVideo(from: videoURL)
                }
            }
            Button("Share") {
                if let videoURL = selectedMediaURL {
                    MainHelper.shareVideo(videoURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Channel Invite", isPresented: $showingInviteActionSheet, titleVisibility: .visible) {
            Button("Accept") {
                openChannelInvite()
            }
            Button("Copy") {
                if let inviteString = selectedInviteString {
                    UIPasteboard.general.string = "channel_invite:\(inviteString)"
                } else {
                    UIPasteboard.general.string = "channel_invite:NOT_AVAILABLE"
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Invoice", isPresented: $showingInvoiceActionSheet, titleVisibility: .visible) {
            Button("Pay") {
                openWallet()
            }
            Button("Copy Address") {
                if let invoice = selectedInvoice {
                    UIPasteboard.general.string = invoice.address
                } else {
                    UIPasteboard.general.string = "invoice:NOT_AVAILABLE"
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    func setSelectedInvoiceString(_ invoiceString: String) {
        selectedInvoiceString = invoiceString
        selectedInvoice = Invoice.decodeInvoiceFromString(invoiceString)
    }
    
    // MARK: Blacklist
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    private func openChannelInvite() {
        guard let channelId = selectedChannelId else { return }

        navigation.joinChannel(channelId: channelId)
    }
    
    private func openWallet() {
        guard let invoice = selectedInvoice else { return }
        print("Paying invoice: \(invoice.address) \(invoice.amount) \(invoice.asset) ")
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

