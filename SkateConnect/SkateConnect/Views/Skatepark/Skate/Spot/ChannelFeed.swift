//
//  ChannelFeed.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import ConnectFramework
import Foundation
import SwiftUI
import NostrSDK
import ExyteChat
import Combine
import CoreLocation

// MARK: - Feed Delegate

class FeedDelegate: ObservableObject, RelayDelegate, EventCreating {
    static let shared = FeedDelegate()

    @Published var messages: [Message] = []
    @Published var lead: Lead?
    
    var relayPool: RelayPool?
    let keychainForNostr = NostrKeychainStorage()

    private var fetchingStoredEvents = true
    private var eventsCancellable: AnyCancellable?
    private var subscriptionIdForMetadata: String?
    private var subscriptionIdForPublicMessages: String?
    
    var viewModelForChannelFeed: ChannelFeedViewModel?
    
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
    
    private func parseEvent(event: NostrEvent) -> Message? {
        let publicKey = PublicKey(hex: event.pubkey)
        let isCurrentUser = publicKey == keychainForNostr.account?.publicKey
        
        return Message(
            id: event.id,
            user: ExyteChat.User(id: String(event.createdAt), name: event.pubkey, avatarURL: nil, isCurrentUser: isCurrentUser),
            createdAt: event.createdDate,
            text: event.content
        )
    }
    
    private var filterForMetadata: Filter? {
        if let eventId = lead?.eventId {
            return Filter(ids: [eventId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
        }
        return nil
    }
    
    private var filterForFeed: Filter? {
        if let eventId = lead?.eventId {
            return Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [eventId]])!
        }
        return nil
    }
    
    public func publishDraft(draft: DraftMessage) {
        guard let account = keychainForNostr.account, let eventId = lead?.eventId else { return }
        
        do {
            let event = try createChannelMessageEvent(withContent: draft.text, eventId: eventId, relayUrl: Constants.RELAY_URL_PRIMAL, signedBy: account)
            relayPool?.publishEvent(event)
        } catch {
            print("Failed to publish draft: \(error.localizedDescription)")
        }
    }
    
    public func updateSubscription() {
        cleanUp()
        
        if let metadataFilter = filterForMetadata {
            subscriptionIdForMetadata = relayPool?.subscribe(with: metadataFilter)
        }
        
        if let feedFilter = filterForFeed {
            subscriptionIdForPublicMessages = relayPool?.subscribe(with: feedFilter)
            
            eventsCancellable = relayPool?.events
                .receive(on: DispatchQueue.main)
                .map { $0.event }
                .removeDuplicates()
                .sink(receiveValue: handleEvent)
        }
    }
    
    private func handleEvent(_ event: NostrEvent) {
        if let message = parseEvent(event: event) {
            if event.kind == .channelCreation {
                if let channel = parseChannel(from: event.content) {
                    lead = Lead(
                        name: channel.name,
                        icon: "🛹",
                        coordinate: CLLocationCoordinate2D(latitude: 33.98698741635913, longitude: -118.47553109622498),
                        eventId: event.id,
                        event: event,
                        channel: channel
                    )
                }
            } else if event.kind == .channelMessage {
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
            relayPool?.closeSubscription(with: $0)
        }
        
        messages.removeAll()
        subscriptionIdForMetadata = nil
        subscriptionIdForPublicMessages = nil
        
        fetchingStoredEvents = true
        
        relayPool?.delegate = self
    }
}

// MARK: - Channel Feed View Model

class ChannelFeedViewModel: ObservableObject {
    @Published var lead: Lead?
    @Published var showEditChannel = false
    @Published var messages: [Message] = []
}

struct ChannelFeed: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: ContentViewModel
    @EnvironmentObject var appConnections: AppConnections
    
    @StateObject var viewModelForChannelFeed = ChannelFeedViewModel()
    
    @ObservedObject var feedDelegate = FeedDelegate.shared

    var landmarks: [Landmark] = AppData().landmarks

    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    init(lead: Lead) {
        feedDelegate.lead = lead
    }
    
    var body: some View {
        ChatView(messages: feedDelegate.messages, chatType: .conversation) { draft in
            feedDelegate.publishDraft(draft: draft)
        }
        .enableLoadMore(pageSize: 3) { message in
        }
        .messageUseMarkdown(messageUseMarkdown: true)
        .onAppear {
            feedDelegate.relayPool = appConnections.relayPool
            feedDelegate.updateSubscription()
        }
        .onDisappear{
            self.feedDelegate.cleanUp()
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
                            Text("\(landmark.name) \(landmark.eventId.prefix(4))...\(landmark.eventId.suffix(4))")
                                .fontWeight(.semibold)
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    } else {
                        if let channel = lead.channel {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(channel.name) \(lead.eventId.prefix(4))...\(lead.eventId.suffix(4))")
                                    .fontWeight(.semibold)
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
            }
        })
    }
}

#Preview {
    ChannelFeed(lead: Lead(name: "Public Chat", icon: "💬", coordinate: AppData().landmarks[0].locationCoordinate, eventId: AppData().landmarks[0].eventId, event: nil, channel: nil))
}
