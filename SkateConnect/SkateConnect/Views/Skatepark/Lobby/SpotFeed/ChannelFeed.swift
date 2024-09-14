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

class FeedDelegate: ObservableObject, RelayDelegate {
    @Published var fetchingStoredEvents = true
    
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            guard case .eose(_) = response else {
                return
            }
            self.fetchingStoredEvents = false
        }
    }
}

class ChannelFeedViewModel: ObservableObject {
    @Published var lead: Lead?
    @Published var showEditChannel = false
}

struct ChannelFeed: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var viewModel: ContentViewModel
    
    let keychainForNostr = NostrKeychainStorage()
    
    @StateObject var viewModelForChannelFeed = ChannelFeedViewModel()
    
    @ObservedObject var feedDelegate = FeedDelegate()
    
    @State private var messages: [Message] = []
    
    private var lead: Lead?
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    init(lead: Lead) {
        self.lead = lead
    }
    
    var body: some View {
        ChatView(messages: messages, chatType: .conversation) { draft in
            publishDraft(draft: draft)
        }
        .enableLoadMore(pageSize: 3) { message in
        }
        .messageUseMarkdown(messageUseMarkdown: true)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $viewModelForChannelFeed.showEditChannel) {
            EditChannel(lead: lead, channel: lead?.channel)
                .environmentObject(viewModelForChannelFeed)
        }
        .onAppear{
            updateSubscription()
        }
        .onDisappear{
            if let subscriptionIdForMetadata {
                viewModel.relayPool.closeSubscription(with: subscriptionIdForMetadata)
            }
            
            if let subscriptionIdForFeed {
                viewModel.relayPool.closeSubscription(with: subscriptionIdForFeed)
            }
        }
        .navigationBarTitle("Test")
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
                if let lead = lead {  // Unwrapping the optional lead
                    if let landmark = findLandmark(lead.eventId) {
                        // Display landmark image and name
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
                        // Display channel name if landmark not found
                        if let channel = lead.channel {  // Unwrapping lead.channel
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
    
    @State private var eventsCancellable: AnyCancellable?
    @State private var subscriptionIdForMetadata: String?
    @State private var subscriptionIdForFeed: String?
    
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
    
    private func publishDraft(draft: DraftMessage) {
        if let account = keychainForNostr.account {
            guard let eventId = lead?.eventId else {
                return
            }
            
            do {
                let event = try createChannelMessageEvent(withContent: draft.text, eventId: eventId, relayUrl: Constants.RELAY_URL_PRIMAL, signedBy: account)
                viewModel.relayPool.publishEvent(event)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func updateSubscription() {
        if let subscriptionIdForMetadata {
            viewModel.relayPool.closeSubscription(with: subscriptionIdForMetadata)
        }
        
        if let subscriptionIdForFeed {
            viewModel.relayPool.closeSubscription(with: subscriptionIdForFeed)
        }
        
        guard let unwrappedFilter = filterForMetadata else {
            return
        }
        
        subscriptionIdForMetadata = viewModel.relayPool.subscribe(with: unwrappedFilter)
        
        guard let unwrappedFilter = filterForFeed else {
            return
        }
        
        subscriptionIdForFeed = viewModel.relayPool.subscribe(with: unwrappedFilter)
        viewModel.relayPool.delegate = self.feedDelegate
        
        eventsCancellable = viewModel.relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                if let message = parseEvent(event: event) {
                    if (event.kind == .channelCreation) {
                        if let channel = parseChannel(from: event.content) {
                            let lead = Lead(
                                name: channel.name,
                                icon: "🛹",
                                coordinate: CLLocationCoordinate2D(
                                    latitude: 33.98698741635913,
                                    longitude: -118.47553109622498),
                                eventId: event.id,
                                event: event,
                                channel: channel
                            )
                            viewModelForChannelFeed.lead = lead
                        }
                    } else
                    if (event.kind == .channelMessage) {
                        if(self.feedDelegate.fetchingStoredEvents) {
                            messages.insert(message, at: 0)
                        } else {
                            messages.append(message)
                        }
                    }
                }
            }
    }
}

#Preview {
    ChannelFeed(lead: Lead(name: "Public Chat", icon: "💬", coordinate: AppData().landmarks[0].locationCoordinate, eventId: AppData().landmarks[0].eventId, event: nil, channel: nil))
}
