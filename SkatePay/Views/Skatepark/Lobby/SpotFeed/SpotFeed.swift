//
//  SpotFeed.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import Foundation
import SwiftUI
import NostrSDK
import ExyteChat
import Combine

class FeedDelegate: ObservableObject, RelayDelegate {
    @Published var fetchingStoredEvents = false
    
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

struct SpotFeed: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var viewModel: ContentViewModel
        
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var chatDelegate = FeedDelegate()
    
    @State private var messages: [Message] = []
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var errorString: String?
    @State private var subscriptionId: String?
            
    private var npub = ""
    private var landmark: Landmark?
    private var connected = true
    
    var landmarks: [Landmark] = SkatePayData().landmarks
    
    func findLandmark(byNpub npub: String) -> Landmark? {
        return landmarks.first { $0.npub == npub }
    }
    
    init(npub: String) {
        self.npub = npub
        self.landmark = findLandmark(byNpub: npub)
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
    
    private func myKeypair() -> Keypair? {
        return Keypair(hex: (keychainForNostr.account?.privateKey.hex)!)
    }
    
    private func recipientPublicKey() -> PublicKey? {
        return PublicKey(npub: npub)
    }
    
    private func myPublicKey() -> PublicKey? {
        return myKeypair()?.publicKey
    }
    
    private func parseEvent(event: NostrEvent) -> Message? {
        var publicKey = PublicKey(hex: event.pubkey)
                
        let isCurrentUser = publicKey != recipientPublicKey()
        publicKey = isCurrentUser ? recipientPublicKey() : publicKey
        
//        let tags = event.tags
        
//        if (!tags.contains{ [myPublicKey()?.hex, recipientPublicKey()?.hex].contains($0.value) }) {
//            return nil
//        }

        do {
            let text = try legacyDecrypt(encryptedContent: event.content, privateKey: myKeypair()!.privateKey, publicKey: publicKey!)
            
            return Message(
                id: event.id,
                user: ExyteChat.User(id: String(event.createdAt), name: event.pubkey, avatarURL: nil, isCurrentUser: isCurrentUser),
                createdAt: event.createdDate,
                text: text
            )
        } catch {
            return nil
        }
    }
    
    private var currentFilter: Filter {
        let authors = [recipientPublicKey()?.hex ?? nil, myPublicKey()?.hex ?? nil]
        
        return Filter(authors: authors.compactMap{ $0 }, kinds: [4])!
    }
    
    private func publishDraft(draft: DraftMessage) {
        guard let recipientPublicKey = recipientPublicKey(),
              let senderKeyPair = myKeypair() else {
            return
        }
        do {
            let directMessage = try legacyEncryptedDirectMessage(withContent: draft.text,
                                                                 toRecipient: recipientPublicKey,
                                                                 signedBy: senderKeyPair)
            viewModel.relayPool.publishEvent(directMessage)
        } catch {
            print(error.localizedDescription)
        }
    }
    private func updateSubscription() {
        if let subscriptionId {
            viewModel.relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = viewModel.relayPool.subscribe(with: currentFilter)
                
        viewModel.relayPool.delegate = self.chatDelegate
                
        eventsCancellable = viewModel.relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
                if let element = parseEvent(event: event) {
                    if(self.chatDelegate.fetchingStoredEvents) {
                        messages.insert(element, at: 0)
                    } else {
                        messages.append(element)
                    }
                }
            }
    }
}

#Preview {
    SpotFeed(npub: SkatePayApp.npub)
}
