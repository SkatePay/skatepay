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

class FeedDelegate: ObservableObject {
    static let shared = FeedDelegate()
    
    @Published var messages: [MessageType] = []
    @Published var lead: Lead?
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var navigation = Navigation.shared
    
    private var eventService = ChannelEventService()
    private var eventsCancellable: AnyCancellable?
    
    private let keychainForNostr = NostrKeychainStorage()
    
    init() {
        eventService = ChannelEventService()
    }

    // MARK: - Subscribe to Channel Events
    public func subscribeToChannelWithId(_channelId: String) {
        cleanUp()

        // Subscribe to channel events via event service
        eventService.subscribeToChannelEvents(channelId: _channelId) { [weak self] events in
            guard let self = self else { return }
            self.handleEvents(events)
        }
    }

    // MARK: - Handle Multiple Events in Bulk
    private func handleEvents(_ events: [NostrEvent]) {
        let newMessages: [MessageType] = []
        
        for event in events {
            if let message = parseEventIntoMessage(event: event) {
                if event.kind == .channelCreation {
                    DispatchQueue.main.async {
                        self.lead = createLead(from: event)
                    }
                    guard let lead = lead else { continue }
                    self.dataManager.saveSpotForLead(lead)
                    navigation.channel = event
                }
                
                // Only add channel messages to newMessages array
                if event.kind == .channelMessage {
                    guard let publicKey = PublicKey(hex: event.pubkey) else { continue }
                    if getBlacklist().contains(publicKey.npub) { continue }
                    
                    // Append messages depending on whether we are fetching stored events or live events
                    if eventService.fetchingStoredEvents {
                        messages.insert(message, at: 0)  // Prepend historical messages
                    } else {
                        messages.append(message)  // Append live messages
                    }
                }
            }
        }

        // Batch update the messages array with new messages
        DispatchQueue.main.async {
            self.messages.append(contentsOf: newMessages)
        }
    }

    // MARK: - Handle Events from Channel
    private func handleEvent(_ event: NostrEvent) {
        // Parse event into a message object
        if let message = parseEventIntoMessage(event: event) {
            if event.kind == .channelCreation {
                // Channel creation event; update lead
                DispatchQueue.main.async {
                    self.lead = createLead(from: event)
                }

                guard let lead = lead else { return }
                self.dataManager.saveSpotForLead(lead)
                navigation.channel = event
            }

            if event.kind == .channelMessage {
                // Channel message event
                guard let publicKey = PublicKey(hex: event.pubkey) else {
                    return
                }
                
                // Check blacklist
                if getBlacklist().contains(publicKey.npub) {
                    return
                }

                // Append messages depending on whether we are fetching stored events or live events
                if eventService.fetchingStoredEvents {
                    messages.insert(message, at: 0)  // Prepend historical messages
                } else {
                    messages.append(message)  // Append live messages
                }
            }
        }
    }

    // MARK: - Publish Draft Message
    public func publishDraft(text: String, kind: Kind = .message) {
        // Delegate to ChannelEventService for publishing the message
        eventService.publishMessage(text, channelId: navigation.channelId, kind: kind)
    }

    // MARK: - Clean Up Subscriptions
    public func cleanUp() {
        // Remove all stored messages and cancel any existing subscriptions
        messages.removeAll()
        eventService.cleanUp()
    }

    // MARK: - Parse Nostr Event into MessageType
    private func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        
        let content = processContent(content: event.content)
        let user = MockUser(senderId: npub, displayName: displayName)

        switch content {
        case .text(let text):
            // Handle text message
            return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
        case .video(let videoURL):
            // Handle video message
            return MockMessage(thumbnail: videoURL, user: user, messageId: event.id, date: event.createdDate)
        case .photo(let imageUrl):
            // Handle photo message
            return MockMessage(imageURL: imageUrl, user: user, messageId: event.id, date: event.createdDate)
        case .invite(let encryptedString):
            // Handle invite message
            guard let invite = decryptChannelInviteFromString(encryptedString: encryptedString) else {
                print("Failed to decrypt channel invite")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }

            guard let image = UIImage(named: "user-skatepay") else {
                print("Failed to load image")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }

            guard let event = invite.event, let lead = createLead(from: event) else {
                print("Failed to create lead from event")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }

            guard let channel = lead.channel,
                  let url = URL(string: "\(Constants.CHANNEL_URL_SKATEPARK)/\(event.id)"),
                  let description = channel.aboutDecoded?.description else {
                print("Failed to generate URL or decode channel description")
                return MockMessage(text: encryptedString, user: user, messageId: "unknown", date: Date())
            }

            let linkItem = MockLinkItem(
                text: "\(lead.icon) Channel Invite",
                attributedText: nil,
                url: url,
                title: "🪧 \(lead.name)",
                teaser: description,
                thumbnailImage: image
            )

            return MockMessage(linkItem: linkItem, user: user, messageId: event.id, date: event.createdDate)
        }
    }

    // MARK: - Blacklist Handling
    func getBlacklist() -> [String] {
        // Get list of blacklisted users (foes)
        return dataManager.fetchFoes().map { $0.npub }
    }
}

struct ChatAreaView: View {
    @Binding var messages: [MessageType]

    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (String) -> Void
    let onSend: (String) -> Void

    var body: some View {
        ChatView(
            messages: $messages,
            onTapAvatar: onTapAvatar,
            onTapVideo: onTapVideo,
            onTapLink: onTapLink,
            onSend: onSend
        )
    }
}
class SelectedUserManager: ObservableObject {
    @Published var npub: String = ""
}
struct ChannelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    @Query(sort: \Spot.channelId) private var spots: [Spot]
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var feedDelegate = FeedDelegate.shared
    
    @State var channelId: String
    @State private var isShowingToolBoxView = false
    
    @State private var keyboardHeight: CGFloat = 0
    
    @StateObject var selectedUserManager = SelectedUserManager() // Local state management

    @State private var isShowingUserDetail = false
    
    @State private var showingConfirmationAlert = false
    @State private var selectedChannelId: String? = nil
    @State private var videoURL: URL?
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    private func openInvite() {
        guard let channelId = selectedChannelId else { return }
        
        if let spot = dataManager.findSpotForChannelId(channelId) {
            navigation.coordinate = spot.locationCoordinate
        }

        self.channelId = channelId
        reload()
    }
        
    func reload() {
        self.navigation.channelId = channelId
        self.feedDelegate.subscribeToChannelWithId(_channelId: channelId)
    }
    
    var body: some View {
        VStack {
            ChatAreaView(
                messages: $feedDelegate.messages,
                onTapAvatar: { senderId in
                    selectedUserManager.npub = senderId
                    isShowingUserDetail.toggle()
                },
                onTapVideo: { message in
                    if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
                        let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
                        
                        self.videoURL = URL(string: videoURLString)
                        navigation.isShowingVideoPlayer.toggle()
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
                self.navigation.channelId = channelId
                self.reload()
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
                            self.navigation.isShowingCameraView = true
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
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $isShowingUserDetail) {
            NavigationView {
                UserDetail(user: getUser(npub: selectedUserManager.npub))
                    .navigationBarItems(leading:
                                            Button(action: {
                        isShowingUserDetail = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Channel")
                            Spacer()
                        }
                    })
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingCameraView) {
            NavigationView {
                CameraView()
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingVideoPlayer) {
            if let videoURL = videoURL {
                NavigationView {
                    VideoPreviewView(url: videoURL)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .uploadVideo)) { notification in
            if let assetURL = notification.userInfo?["assetURL"] as? String {
                feedDelegate.publishDraft(text: assetURL, kind: .video)
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
