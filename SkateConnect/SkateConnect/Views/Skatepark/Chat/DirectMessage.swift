//
//  DirectMessage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Combine
import ConnectFramework
import ExyteChat
import Foundation
import NostrSDK
import SwiftUI
import UIKit

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

struct DirectMessage: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.presentationMode) private var presentationMode

    @ObservedObject var network = Network.shared
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var navigation = Navigation.shared
    
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var chatDelegate = ChatDelegate()
    
    @State private var messages: [Message] = []
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var errorString: String?
    @State private var subscriptionId: String?
    
    @State private var isShowingUserDetail = false
    
    @State private var showAlertForReporting = false
    @State private var showAlertForAddingPark = false
    
    private var user: User
    private var message: String
    
    var connected: Bool { relayPool.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) }
    
    init(user: User, message: String = "") {
        self.user = user
        self.message = message
    }
    
    func formatName() -> String {
        if let friend = self.dataManager.findFriend(user.npub) {
            return friend.name
        } else {
            return friendlyKey(npub: user.npub)
        }
    }
    
    func formatImage() -> Image {
        return user.image
    }
    
    var body: some View {
        ExyteChat.ChatView(messages: messages, chatType: .conversation) { draft in
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
                Button(action: {
                    if (!navigation.isShowingUserDetail) {
                        self.isShowingUserDetail.toggle()
                    }
                }) {
                    HStack {
                        Image("user-skatepay")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 35, height: 35)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(formatName())
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
        }
        .fullScreenCover(isPresented: $isShowingUserDetail) {
            NavigationView {
                UserDetail(user: getUser(npub: user.npub))
                    .navigationBarItems(leading:
                                            Button(action: {
                        isShowingUserDetail = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Chat")
                            Spacer()
                        }
                    })
            }
        }
        .alert("Confirm Report", isPresented: $showAlertForReporting) {
            Button("No", role: .cancel) {
            }
            Button("Yes") {
                publishEvent(content: "Hi, I would like to report \(friendlyKey(npub: message)).")
            }
        } message: {
            Text("Do you want to continue with the report on \(friendlyKey(npub: message))?")
        }
        .alert("Confirm Park Request", isPresented: $showAlertForAddingPark) {
            Button("No", role: .cancel) {
            }
            Button("Yes") {
                publishEvent(content: "Hi, I would like to add my park to your directory. Please tell me how to do that.")
            }
        } message: {
            Text("Do you want to see your park on SkateConnect?")
        }
        .onAppear{
            updateSubscription()

            if (message.isEmpty) {
                return
            }

            if (message.contains("request")) {
                showAlertForAddingPark.toggle()
            } else {
                showAlertForReporting.toggle()
            }
        }
        .onDisappear{
            if let subscriptionId {
                relayPool.closeSubscription(with: subscriptionId)
            }
        }
    }
    
    private var relayPool: RelayPool {
        return network.getRelayPool()
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
    
    private func publishEvent(content: String) {
        guard let recipientPublicKey = recipientPublicKey(),
              let senderKeyPair = myKeypair() else {
            return
        }
        do {
            let directMessage = try legacyEncryptedDirectMessage(withContent: content,
                                                                 toRecipient: recipientPublicKey,
                                                                 signedBy: senderKeyPair)
            relayPool.publishEvent(directMessage)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func publishDraft(draft: DraftMessage) {
        let content = draft.text
        publishEvent(content: content)
    }
    
    private func updateSubscription() {        
        chatDelegate.fetchingStoredEvents = true
        
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        if let unwrappedFilter = currentFilter {
            subscriptionId = relayPool.subscribe(with: unwrappedFilter)
        } else {
            print("currentFilter is nil, unable to subscribe")
        }
        
        relayPool.delegate = self.chatDelegate
                
        eventsCancellable = relayPool.events
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
    DirectMessage(user: AppData().users[0])
}
