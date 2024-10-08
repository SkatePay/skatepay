//
//  DirectChat.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Foundation
import SwiftUI
import NostrSDK
import ExyteChat
import Combine

class ChatDelegate: ObservableObject, RelayDelegate {
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

struct DirectChat: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var viewModel: ContentViewModel
        
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var chatDelegate = ChatDelegate()
    
    @State private var messages: [Message] = []
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var errorString: String?
    @State private var subscriptionId: String?
            
    private var user: User
    
    var connected: Bool { viewModel.relayPool.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) }
    
    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        ChatView(messages: messages, chatType: .conversation) { draft in
            publishDraft(draft: draft)
        }
        .enableLoadMore(pageSize: 3) { message in
        }
        .messageUseMarkdown(messageUseMarkdown: true)
        .navigationBarBackButtonHidden()
        .toolbar{
            ToolbarItem(placement: .navigationBarLeading) {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    Image("backArrow", bundle: .current)
                }
            }
            
            ToolbarItem(placement: .principal) {
                HStack {
                    user.image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(user.name)
                            .fontWeight(.semibold)
                            .font(.headline)
                            .foregroundColor(.black)
                        Text(connected ? "online" : "offline")
                            .font(.footnote)
                            .foregroundColor(Color(hex: "AFB3B8"))
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
        }
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
        return PublicKey(npub: user.npub)
    }
    
    private func parseEvent(event: NostrEvent) -> Message? {
        var publicKey = PublicKey(hex: event.pubkey)
                
        let isCurrentUser = publicKey != recipientPublicKey()
        publicKey = isCurrentUser ? recipientPublicKey() : publicKey

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
    
//    private var currentFilter: Filter {
//        let authors = [recipientPublicKey()?.hex ?? nil, myPublicKey()?.hex ?? nil]
//        
//        print(authors)
//        return Filter(authors: authors.compactMap{ $0 }, kinds: [4])!
//    }
    
    private var currentFilter: Filter? {
        guard let account = keychainForNostr.account else {
            print("Error: Failed to create Filter")
            return nil
        }
        
        guard let hex = recipientPublicKey()?.hex else {
            print("Error: Failed to create Filter")
            return nil
        }
        
        let authors = [hex, account.publicKey.hex]
                
        let filter = Filter(authors: authors.compactMap{ $0 }, kinds: [4], tags: ["p" : [account.publicKey.hex, hex]])
        
        return filter
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
        
        if let unwrappedFilter = currentFilter {
            subscriptionId = viewModel.relayPool.subscribe(with: unwrappedFilter)
        } else {
            // Handle the case where currentFilter is nil
            print("currentFilter is nil, unable to subscribe")
        }
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
    DirectChat(user: AppData().users[0])
}
