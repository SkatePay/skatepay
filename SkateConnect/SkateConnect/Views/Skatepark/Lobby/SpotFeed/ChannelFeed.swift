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
    @Published var metadataForChannel: NostrEvent?
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
    
    private var eventId = ""
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    init(eventId: String) {
        self.eventId = eventId
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
            EditChannel()
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
                        if let landmark = findLandmark(eventId) {
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
    
    private var filterForMetadata: Filter {
        return Filter(ids: [eventId], kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])!
    }
    
    private var filterForFeed: Filter {
        return Filter(kinds: [EventKind.channelMessage.rawValue], tags: ["e": [eventId]])!
    }
    
    private func publishDraft(draft: DraftMessage) {
        if let account = keychainForNostr.account {
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
        
        subscriptionIdForMetadata = viewModel.relayPool.subscribe(with: filterForMetadata)
        subscriptionIdForFeed = viewModel.relayPool.subscribe(with: filterForFeed)
        
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
                        viewModelForChannelFeed.metadataForChannel = event
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
    ChannelFeed(eventId: Constants.NCHANNEL_ID)
}
