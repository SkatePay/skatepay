//
//  DirectChat.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Foundation
import SwiftUI
import NostrSDK
import ExyteChat
import Combine

struct DirectChat: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var relayPool: RelayPool
    @EnvironmentObject var hostStore: HostStore
    
    @State private var events: [NostrEvent] = []
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
    
    @AppStorage("filter") var filter: String = ""
    
    private var user: User

    var connected: Bool { relayPool.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) }

    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        ChatView(messages: parseEvents, chatType: .conversation) { draft in
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
                relayPool.closeSubscription(with: subscriptionId)
            }
        }
    }
    
    private func myKeypair() -> Keypair? {
        return Keypair(hex: hostStore.host.privateKey)
    }

    private func recipientPublicKey() -> PublicKey? {
        return PublicKey(npub: user.npub)
    }
    
    private func myPublicKey() -> PublicKey? {
        return myKeypair()?.publicKey
    }
    
    private var parseEvents: [Message] {
        let messages = events.compactMap {
            
            var publicKey = PublicKey(hex: $0.pubkey)
            
            let isCurrentUser = publicKey != recipientPublicKey();
            publicKey = isCurrentUser ? recipientPublicKey() : publicKey
            
            do {
                let text = try legacyDecrypt(encryptedContent: $0.content, privateKey: myKeypair()!.privateKey, publicKey: publicKey!)
                
                return Message(
                    id: $0.id,
                    user: ExyteChat.User(id: $0.id, name: $0.pubkey, avatarURL: nil, isCurrentUser: isCurrentUser),
                    createdAt: $0.createdDate,
                    text: text
                )
            } catch {
                return nil
            }
        }
        
        return messages
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
            relayPool.publishEvent(directMessage)
        } catch {
            print(error.localizedDescription)
        }
    }
    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = relayPool.subscribe(with: currentFilter)
        
        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                $0.event
            }
            .removeDuplicates()
            .sink { event in
                events.insert(event, at: 0)
            }
    }
}

extension Color {
    static var exampleBlue = Color(hex: "#4962FF")
    static var examplePickerBg = Color(hex: "1F1F1F")
}

#Preview {
    DirectChat(user: ModelData().users[0])
}
