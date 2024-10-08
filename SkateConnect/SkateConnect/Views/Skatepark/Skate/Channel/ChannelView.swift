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

class FeedDelegate: ObservableObject, RelayDelegate, EventCreating {
    static let shared = FeedDelegate()
    
    @Published var messages: [MessageType] = []
    @Published var lead: Lead?
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject var network = Network.shared
    @ObservedObject var navigation = Navigation.shared
    
    let keychainForNostr = NostrKeychainStorage()
    
    private var fetchingStoredEvents = true
    private var eventsCancellable: AnyCancellable?
    private var subscriptionIdForMetadata: String?
    private var subscriptionIdForPublicMessages: String?
    
    var getBlacklist: () -> [String]
    
    private var relayPool: RelayPool {
        return network.getRelayPool()
    }
    
    init() {
        self.getBlacklist = { [] }
    }
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(let subscriptionId) = response else {
                return
            }
            if (subscriptionId == self.subscriptionIdForPublicMessages) {
                self.fetchingStoredEvents = false
            }
        }
    }
    
    private func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        
        let npub = publicKey?.npub ?? ""
        
        let displayName = isCurrentUser ? "You" : friendlyKey(npub: npub)
        
        let content = processContent(content: event.content)
        
        let user = MockUser(senderId: npub, displayName: displayName)
        
        switch content {
        case .text(let text):
            return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
        case .video(let videoURL):
            return MockMessage(thumbnail: videoURL, user: user, messageId: event.id, date: event.createdDate)
        case .photo(let imageUrl):
            return MockMessage(imageURL: imageUrl, user: user, messageId: event.id, date: event.createdDate)
        case .invite(let encryptedString):
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
    
    private var filterForMetadata: Filter? {
        return Filter(ids: [navigation.channelId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
    }
    
    private var filterForFeed: Filter? {
        return Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [navigation.channelId]], limit: 32)!
    }
    
    public func publishDraft(text: String) {
        guard let account = keychainForNostr.account else { return }
        
        do {
            let contentStructure = ContentStructure(content: text, kind: .message)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(contentStructure)
            let content  = String(data: data, encoding: .utf8) ?? text
            
            let event = try createChannelMessageEvent(withContent: content, eventId: navigation.channelId, relayUrl: Constants.RELAY_URL_PRIMAL, signedBy: account)
            relayPool.publishEvent(event)
        } catch {
            print("Failed to publish draft: \(error.localizedDescription)")
        }
    }
    
    public func updateSubscription() {
        cleanUp()
        
        if let metadataFilter = filterForMetadata {
            subscriptionIdForMetadata = relayPool.subscribe(with: metadataFilter)
        }
        
        if let feedFilter = filterForFeed {
            subscriptionIdForPublicMessages = relayPool.subscribe(with: feedFilter)
        }
        
        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map { $0.event }
            .removeDuplicates()
            .sink(receiveValue: handleEvent)
    }
    
    private func handleEvent(_ event: NostrEvent) {
        if let message = parseEventIntoMessage(event: event) {
            if event.kind == .channelCreation {
                DispatchQueue.main.async {
                    self.lead = createLead(from: event)
                }
                
                guard let lead = lead else { return }
                self.dataManager.saveSpotForLead(lead)
                navigation.channel = event
            }
            
            if event.kind == .channelMessage {
                guard let publicKey = PublicKey(hex: event.pubkey) else {
                    return
                }
                
                if (getBlacklist().contains(publicKey.npub)) {
                    return
                }
                
                if fetchingStoredEvents {
                    messages.insert(message, at: 0)
                } else {
                    messages.append(message)
                }
            }
        }
    }
    
    public func cleanUp() {
        [subscriptionIdForMetadata, subscriptionIdForPublicMessages].compactMap { $0 }.forEach {
            relayPool.closeSubscription(with: $0)
        }
        
        messages.removeAll()
        subscriptionIdForMetadata = nil
        subscriptionIdForPublicMessages = nil
        
        fetchingStoredEvents = true
        
        relayPool.delegate = self
    }
    
    public func publishDraft(text: String, kind: Kind = .message) {
        guard let account = keychainForNostr.account else { return }
        
        do {
            let contentStructure = ContentStructure(content: text, kind: kind)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(contentStructure)
            let content  = String(data: data, encoding: .utf8) ?? text
            
            let event = try createChannelMessageEvent(withContent: content, eventId: navigation.channelId, relayUrl: Constants.RELAY_URL_PRIMAL, signedBy: account)
            relayPool.publishEvent(event)
        } catch {
            print("Failed to publish draft: \(error.localizedDescription)")
        }
    }
}

struct ChannelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    @Query(sort: \Spot.channelId) private var spots: [Spot]
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var feedDelegate = FeedDelegate.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var isShowingToolBoxView = false
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var npub = ""
    
    @State private var showingConfirmationAlert = false
    @State private var selectedChannelId: String? = nil
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    func findSpotForChannelId(_ channelId: String) -> Spot? {
        return spots.first { $0.channelId == channelId }
    }
    
    // MARK: onMessageTap delegates
    @State private var videoURL: URL?
    
    private func showMenu(_ senderId: String) {
        if senderId.isEmpty {
            print("unknown sender")
        } else {
            self.npub = senderId
            navigation.isShowingUserDetail.toggle()
        }
    }
    
    private func openVideoPlayer(_ message: MessageType) {
        if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
            let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
            
            self.videoURL = URL(string: videoURLString)
            navigation.isShowingVideoPlayer.toggle()
        }
    }
    
    private func openLink(_ channelId: String) {
        if let spot = findSpotForChannelId(channelId) {
            navigation.coordinate = spot.locationCoordinate
            locationManager.panMapToCachedCoordinate()
        }

        navigation.goToChannelWithId(channelId)
        self.reload()
    }
        
    private func onTapLink(_ channelId: String) {
        selectedChannelId = channelId
        showingConfirmationAlert = true
    }
    
    private func onSend(text: String) {
        feedDelegate.publishDraft(text: text)
    }
    
    func reload() {
        self.feedDelegate.updateSubscription()
    }
    
    var body: some View {
        VStack {
            ChatView(
                messages: $feedDelegate.messages,
                onTapAvatar: showMenu,
                onTapVideo: openVideoPlayer,
                onTapLink: onTapLink,
                onSend: onSend
            )
            .onAppear {
                feedDelegate.getBlacklist = getBlacklist
                
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
                    if let channelId = selectedChannelId {
                        openLink(channelId)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $isShowingToolBoxView) {
            ToolBoxView()
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $navigation.isShowingUserDetail) {
            let user = getUser(npub: self.npub)
            
            NavigationView {
                UserDetail(user: user)
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.isShowingUserDetail = false
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
            self.feedDelegate.updateSubscription()
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
    ChannelView()
}
