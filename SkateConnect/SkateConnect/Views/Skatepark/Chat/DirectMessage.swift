//
//  DirectMessage.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import SwiftUI
import UIKit

class DirectMessageDelegate: ObservableObject, RelayDelegate {
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
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var network = Network.shared
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var locationManager = LocationManager.shared

    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var chatDelegate = DirectMessageDelegate()
    @ObservedObject var messageHandler = MessageHandler()
    
    @State private var eventsCancellable: AnyCancellable?
    
    @State private var errorString: String?
    @State private var subscriptionId: String?
    
    @State private var isShowingUserDetail = false
    
    @State private var showAlertForReporting = false
    @State private var showAlertForAddingPark = false
    
    @State private var showingConfirmationAlert = false
    @State private var selectedChannelId: String? = nil
    
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
    
    @State private var videoURL: URL?
    
    private func showMenu(_ senderId: String) {
//        if senderId.isEmpty {
//            print("unknown sender")
//        } else {
//            self.npub = senderId
//            navigation.isShowingUserDetail.toggle()
//        }
    }
    
    private func openVideoPlayer(_ message: MessageType) {
//        if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
//            let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
//            
//            self.videoURL = URL(string: videoURLString)
//            navigation.isShowingVideoPlayer.toggle()
//        }
    }
    
    private func openLink(_ channelId: String) {
        if let spot = dataManager.findSpotForChannelId(channelId) {
            navigation.coordinate = spot.locationCoordinate
            locationManager.panMapToCachedCoordinate()
        }

        navigation.goToChannelWithId(channelId)
//        self.reload()
    }
        
    private func onTapLink(_ channelId: String) {
        selectedChannelId = channelId
        showingConfirmationAlert = true
    }
    
    private func onSend(text: String) {
        publishEvent(text: text)
    }
    
    var body: some View {
        ChatView(
            messages: $messageHandler.messages,
            onTapAvatar: showMenu,
            onTapVideo: openVideoPlayer,
            onTapLink: onTapLink,
            onSend: onSend
        )
        .navigationBarBackButtonHidden()
        .navigationBarItems(
            leading:
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                    }
                    
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
                                Text(connected ? "online" : "offline")
                                    .font(.footnote)
                                    .foregroundColor(Color(hex: "AFB3B8"))
                            }
                            Spacer()
                        }
                        .padding(.leading, 10)
                    }
                },
            trailing:
                HStack(spacing: 16) {
                    Button(action: {
//                        self.isShowingToolBoxView.toggle()
                    }) {
                        Image(systemName: "network")
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
        .alert(isPresented: $showingConfirmationAlert) {
            Alert(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to join this channel?"),
                primaryButton: .default(Text("Yes")) {
                    if let channelId = selectedChannelId {
                        openLink(channelId)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Confirm Report", isPresented: $showAlertForReporting) {
            Button("No", role: .cancel) {
            }
            Button("Yes") {
                publishEvent(text: "Hi, I would like to report \(friendlyKey(npub: message)).")
            }
        } message: {
            Text("Do you want to continue with the report on \(friendlyKey(npub: message))?")
        }
        .alert("Confirm Park Request", isPresented: $showAlertForAddingPark) {
            Button("No", role: .cancel) {
            }
            Button("Yes") {
                publishEvent(text: "Hi, I would like to add my park to your directory. Please tell me how to do that.")
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
        .modifier(IgnoresSafeArea()) //fixes issue with IBAV placement when keyboard appear
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
    
    private func publishEvent(text: String) {
        guard let account = keychainForNostr.account else { return }

        guard let recipientPublicKey = recipientPublicKey() else { return }
        
        do {
            let contentStructure = ContentStructure(content: text, kind: .message)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(contentStructure)
            let content  = String(data: data, encoding: .utf8) ?? text
            
            let directMessage = try legacyEncryptedDirectMessage(withContent: content,
                                                                 toRecipient: recipientPublicKey,
                                                                 signedBy: account)
            relayPool.publishEvent(directMessage)
        } catch {
            print(error.localizedDescription)
        }
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
                if let message = parseEventIntoMessage(event: event) {
                    if(self.chatDelegate.fetchingStoredEvents) {
                        messageHandler.messages.insert(message, at: 0)
                    } else {
                        messageHandler.messages.append(message)
                    }
                }
            }
    }
    
    private func parseEventIntoMessage(event: NostrEvent) -> MessageType? {
        var publicKey = PublicKey(hex: event.pubkey)
                
        let isCurrentUser = publicKey != recipientPublicKey()
        publicKey = isCurrentUser ? recipientPublicKey() : publicKey

        do {
            let text = try legacyDecrypt(encryptedContent: event.content, privateKey: myKeypair()!.privateKey, publicKey: publicKey!)
            
            let builder = NostrEvent.Builder(nostrEvent: event)
            let decryptedEvent =  builder.content(text).build(pubkey: event.pubkey)
            
            return messageHandler.parseEventIntoMessage(event: decryptedEvent)
        } catch {
            return nil
        }
    }
}

#Preview {
    DirectMessage(user: AppData().users[0])
}
