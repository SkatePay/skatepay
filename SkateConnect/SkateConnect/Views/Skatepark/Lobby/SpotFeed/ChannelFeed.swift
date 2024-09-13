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

struct ChannelFeed: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var viewModel: ContentViewModel
    
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var feedDelegate = FeedDelegate()
    
    @State private var messages: [Message] = []
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var errorString: String?
    @State private var subscriptionId: String?
    
    private var eventId = ""
    private var connected = true
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func findLandmark(byNpub npub: String) -> Landmark? {
        return landmarks.first { $0.npub == npub }
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
        //        .toolbar{
        //            ToolbarItem(placement: .navigationBarLeading) {
        //                Button { presentationMode.wrappedValue.dismiss() } label: {
        //                    Image("backArrow", bundle: .current)
        //                }
        //            }
        //
        //            ToolbarItem(placement: .principal) {
        //                HStack {
        //                    if let image = landmark?.image {
        //                       image
        //                        .resizable()
        //                        .scaledToFill()
        //                        .frame(width: 35, height: 35)
        //                        .clipShape(Circle())
        //                    }
        //                    if let name = landmark?.name {
        //                        VStack(alignment: .leading, spacing: 0) {
        //                            Text(name)
        //                                .fontWeight(.semibold)
        //                                .font(.headline)
        //                                .foregroundColor(.black)
        //                            Text(connected ? "online" : "offline")
        //                                .font(.footnote)
        //                                .foregroundColor(Color(hex: "AFB3B8"))
        //                        }
        //                    }
        //                    Spacer()
        //                }
        //                .padding(.leading, 10)
        //            }
        //        }
        .onAppear{
            updateSubscription()
        }
        .onDisappear{
            if let subscriptionId {
                viewModel.relayPool.closeSubscription(with: subscriptionId)
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
    
    private var currentFilter: Filter {
        return Filter(kinds: [EventKind.channelMetadata.rawValue, EventKind.channelMessage.rawValue], tags: ["e": [eventId]])!
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
        if let subscriptionId {
            viewModel.relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = viewModel.relayPool.subscribe(with: currentFilter)
        
        viewModel.relayPool.delegate = self.feedDelegate
        
        eventsCancellable = viewModel.relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                if let element = parseEvent(event: event) {
                    if(self.feedDelegate.fetchingStoredEvents) {
                        messages.insert(element, at: 0)
                    } else {
                        messages.append(element)
                    }
                }
            }
    }
}

#Preview {
    ChannelFeed(eventId: Constants.NCHANNEL_ID)
}
