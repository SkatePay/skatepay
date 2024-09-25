//
//  ChannelFeed.swift
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
    let kind: String
}

class FeedDelegate: ObservableObject, RelayDelegate, EventCreating {
    static let shared = FeedDelegate()
    
    @Published var messages: [MessageType] = []
    
    @Published var lead: Lead?
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var networkConnections = NetworkConnections.shared
    
    let keychainForNostr = NostrKeychainStorage()
    
    private var fetchingStoredEvents = true
    private var eventsCancellable: AnyCancellable?
    private var subscriptionIdForMetadata: String?
    private var subscriptionIdForPublicMessages: String?
    
    var viewModelForChannelFeed: ChannelFeedViewModel?
    
    var getBlacklist: () -> [String]
    
    private var relayPool: RelayPool {
        return networkConnections.getRelayPool()
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
        
        let user = MockUser(senderId: npub, displayName: displayName)
        
        var text = event.content
        
        do {
            let decoder = JSONDecoder()
            let decodedStructure = try decoder.decode(ContentStructure.self, from: event.content.data(using: .utf8)!)
            
            text = decodedStructure.content
        } catch {
//            print("Error decoding: \(error)")
        }
        
        return MockMessage(text: text, user: user, messageId: event.id, date: event.createdDate)
    }
    
    private var filterForMetadata: Filter? {
        if let eventId = lead?.eventId {
            return Filter(ids: [eventId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
        }
        return nil
    }
    
    private var filterForFeed: Filter? {
        if let eventId = lead?.eventId {
            return Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [eventId]], limit: 32)!
        }
        return nil
    }
    
    public func publishDraft(text: String) {
        guard let account = keychainForNostr.account, let eventId = lead?.eventId else { return }
        
        do {
            let contentStructure = ContentStructure(content: text, kind: "message")
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(contentStructure)
            let content  = String(data: data, encoding: .utf8) ?? text
            print(content)
            
            let event = try createChannelMessageEvent(withContent: content, eventId: eventId, relayUrl: Constants.RELAY_URL_PRIMAL, signedBy: account)
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
            
            eventsCancellable = relayPool.events
                .receive(on: DispatchQueue.main)
                .map { $0.event }
                .removeDuplicates()
                .sink(receiveValue: handleEvent)
        }
    }
    
    private func handleEvent(_ event: NostrEvent) {
        if let message = parseEventIntoMessage(event: event) {
            if event.kind == .channelCreation {
                // Ignore bootstrapped values
                if (event.id == AppData().landmarks[0].eventId ) {
                    return
                }
                
                self.lead = createLead(from: event)
                
                guard let lead = lead else { return }
                self.dataManager.createSpot(lead: lead)
            } else if event.kind == .channelMessage {
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
}

// MARK: - Channel Feed View Model

class ChannelFeedViewModel: ObservableObject {
    @Published var lead: Lead?
    @Published var showEditChannel = false
}

struct ChannelFeed: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Foe.npub) private var foes: [Foe]
    @Query(sort: \Spot.channelId) private var spots: [Spot]
    
    @ObservedObject var dataManager = DataManager.shared
    
    @StateObject var viewModelForChannelFeed = ChannelFeedViewModel()
    
    @ObservedObject var navigation = NavigationManager.shared
    @ObservedObject var feedDelegate = FeedDelegate.shared
    @ObservedObject var lobby = Lobby.shared
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var showAlert = false
    @State var npub = ""
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func getBlacklist() -> [String] {
        return foes.map({$0.npub})
    }
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    func findSpot(_ eventId: String) -> Spot? {
        return spots.first { $0.channelId == eventId }
    }
    
    init(channelId: String) {
        let lead = lobby.leads[channelId] ??
        Lead(name: "Private Group Chat",
             icon: "💬",
             coordinate: AppData().landmarks[0].locationCoordinate,
             eventId: channelId,
             event: nil,
             channel: Channel(
                name: "Private Channel",
                about: "Private Channel",
                picture: "",
                relays: [Constants.RELAY_URL_PRIMAL]
             )
        )
        
        feedDelegate.lead = lead
    }
    
    func showMenu(_ senderId: String) {
        if senderId.isEmpty {
            print("unknown sender")
        } else {
            self.npub = senderId
            navigation.isShowingUserDetail.toggle()
        }
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
    
    var messageKit: some View {
        VStack {
            MessagesView(messages: $feedDelegate.messages, onTapAvatar: showMenu)
                .onAppear {
                    self.feedDelegate.updateSubscription()
                    setupKeyboardObservers()
                    feedDelegate.getBlacklist = getBlacklist
                }
                .onAppear(perform: observeNotification)
            
                .onDisappear {
                    self.feedDelegate.cleanUp()
                    NotificationCenter.default.removeObserver(self)
                }
                .navigationBarBackButtonHidden()
                .sheet(isPresented: $viewModelForChannelFeed.showEditChannel) {
                    if let lead = feedDelegate.lead {
                        EditChannel(lead: lead, channel: lead.channel)
                            .environmentObject(viewModelForChannelFeed)
                    }
                }
                .navigationBarItems(leading:
                                        HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                    }
                    Button(action: {
                        viewModelForChannelFeed.showEditChannel.toggle()
                    }) {
                        if let lead = feedDelegate.lead {
                            if let landmark = findLandmark(lead.eventId) {
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
                            } else {
                                if let channel = lead.channel {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("\(channel.name)")
                                            .fontWeight(.semibold)
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    }
                })
        }
        .fullScreenCover(isPresented: $navigation.isShowingUserDetail) {
            let user = User(
                id: 1,
                name: friendlyKey(npub: self.npub),
                npub: self.npub,
                solanaAddress: "SolanaAddress1...",
                relayUrl: Constants.RELAY_URL_PRIMAL,
                isFavorite: false,
                note: "Not provided.",
                imageName: "user-skatepay"
            )
            NavigationView {
                UserDetail(user: user)
                    .navigationBarTitle("User Detail")
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
        .padding(.bottom, keyboardHeight)
        .modifier(IgnoresSafeArea()) //fixes issue with IBAV placement when keyboard appear
    }
    
    var body: some View {
        messageKit
    }
    
    // MARK: Private
    
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
    ChannelFeed(channelId: "")
}
