//
//  ChannelView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import ConnectFramework
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
    case message
    case subscriber
}

class FeedDelegate: ObservableObject, RelayDelegate, EventCreating {
    static let shared = FeedDelegate()
    
    @Published var messages: [MessageType] = []
    
    @ObservedObject var dataManager = DataManager.shared
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
        case .invite(let channelId):
            if let url = URL(string: "https://support.skatepark.chat"),
               let image = UIImage(named: "user-skatepay") {
                let linkItem = MockLinkItem(
                    text: "🌐 Channel Invite",
                    attributedText: nil,
                    url: url,
                    title: "Enter Channel 🚪",
                    teaser: channelId,
                    thumbnailImage: image
                )
                return MockMessage(linkItem: linkItem, user: user, messageId: event.id, date: event.createdDate)
            } else {
                // Handle the error for invalid URL or missing image
                print("Failed to initialize URL or image")
                return MockMessage(text: channelId, user: user, messageId: event.id, date: event.createdDate)
            }
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
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var isShowingSendTo = false
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var showAlert = false
    @State private var npub = ""
    @State private var lead: Lead?
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func getBlacklist() -> [String] {
        return foes.map({$0.npub})
    }
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    func findSpotForChannelId(_ channelId: String) -> Spot? {
        return spots.first { $0.channelId == channelId }
    }
    
    func initializeLead(channelId: String) -> Lead {
        let lead = lobby.findLead(byChannelId: channelId) ??
        Lead(name: "Private Group Chat",
             icon: "💬",
             coordinate: AppData().landmarks[0].locationCoordinate,
             channelId: channelId,
             event: nil,
             channel: Channel(
                name: "Private Channel",
                about: "Private Channel",
                picture: "",
                relays: [Constants.RELAY_URL_PRIMAL]
             )
        )
        return lead
    }
    
    // MARK: onMessageTap delegates
    @State private var videoURL: URL?
    
    func openVideoPlayer(_ message: MessageType) {
        if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
            
            let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
            
            self.videoURL = URL(string: videoURLString)
            navigation.isShowingVideoPlayer.toggle()
        }
    }
    
    func showMenu(_ senderId: String) {
        if senderId.isEmpty {
            print("unknown sender")
        } else {
            self.npub = senderId
            navigation.isShowingUserDetail.toggle()
        }
    }
    
    func reload() {
        self.feedDelegate.updateSubscription()
        self.lead = initializeLead(channelId: navigation.channelId)
    }
    
    func openLink(_ channelId: String) {
        if let spot = findSpotForChannelId(channelId) {
            navigation.coordinate = spot.locationCoordinate
            locationManager.panMapToCachedCoordinate()
        }

        navigation.goToChannelWithId(channelId)
        self.reload()
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
    
    var body: some View {
        VStack {
            ChatView(
                messages: $feedDelegate.messages,
                onTapAvatar: showMenu,
                onTapVideo: openVideoPlayer,
                onTapLink: openLink
            )
                .onAppear {
                    setupKeyboardObservers()
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
                    if let lead = lead {
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
                                if let lead = self.lead {
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
                                self.isShowingSendTo.toggle()
                            }) {
                                Image(systemName: "person.crop.rectangle")
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
        .sheet(isPresented: $isShowingSendTo) {
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
        .padding(.bottom, keyboardHeight)
        .modifier(IgnoresSafeArea()) //fixes issue with IBAV placement when keyboard appear
    }
    
    // MARK: Keyboard Delegates
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardRectangle = keyboardFrame.cgRectValue
                keyboardHeight = keyboardRectangle.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private struct IgnoresSafeArea: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 14.0, *) {
                content.ignoresSafeArea(.keyboard, edges: .bottom)
            } else {
                content
            }
        }
    }
}

struct OnkeyboardAppearHandler: ViewModifier {
    var handler: (Bool) -> Void
    func body(content: Content) -> some View {
        content
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    handler(true)
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    handler(false)
                }
            }
    }
}

extension View {
    public func onKeyboardAppear(handler: @escaping (Bool) -> Void) -> some View {
        modifier(OnkeyboardAppearHandler(handler: handler))
    }
}

#Preview {
    ChannelView()
}
