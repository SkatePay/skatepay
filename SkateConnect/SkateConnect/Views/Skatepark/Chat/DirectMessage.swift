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

struct DirectMessage: View, LegacyDirectMessageEncrypting, EventCreating {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var dataManager: DataManager
    
    @ObservedObject private var messageHandler = MessageHandler()

    private var user: User
    private var message: String

    @State private var eventsCancellable: AnyCancellable?

    @State private var isShowingCameraView = false
    @State private var isShowingVideoPlayer = false
    
    @State private var showingConfirmationAlert = false
    @State private var showAlertForReporting = false
    @State private var showAlertForAddingPark = false

    @State private var selectedChannelId: String?
    @State private var videoURL: URL?

    @State private var shouldScrollToBottom = true

    private var connected: Bool {
        network.relayPool?.relays.contains { $0.url == URL(string: user.relayUrl) } ?? false
    }

    func formatName() -> String {
        dataManager.findFriend(user.npub)?.name ?? friendlyKey(npub: user.npub)
    }

    init(user: User, message: String = "") {
        self.user = user
        self.message = message
    }

    private let keychainForNostr = NostrKeychainStorage()
    
    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
    }
    
    var body: some View {
        ChatView(
            currentUser: getCurrentUser(),
            messages: $messageHandler.messages,
            shouldScrollToBottom: $shouldScrollToBottom,
            onTapAvatar: { _ in print("Avatar tapped") },
            onTapVideo: handleVideoTap,
            onTapLink: { channelId in selectedChannelId = channelId; showingConfirmationAlert = true },
            onSend: publishEvent
        )
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: backButton, trailing: actionButtons)
        .alert(isPresented: $showingConfirmationAlert) {
            Alert(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to join this channel?"),
                primaryButton: .default(Text("Yes")) { openChannelInvite() },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            setupSubscription()
        }
        .onDisappear { cleanupSubscription() }
        .modifier(IgnoresSafeArea()) // Fixes keyboard issue
    }


}

// MARK: - Nostr
private extension DirectMessage {
    private func setupSubscription() {
        if let service = network.eventServiceForDirect {
            service.fetchingStoredEvents = true

            if let pool = network.relayPool {
                service.subscriptionIdForPrivateMessages.map { pool.closeSubscription(with: $0) }

                if let filter = currentFilter {
                    service.subscriptionIdForPrivateMessages = pool.subscribe(with: filter)
                } else {
                    print("Failed to create filter for subscription")
                }

                pool.delegate = network
                eventsCancellable = pool.events
                    .receive(on: DispatchQueue.main)
                    .map { $0.event }
                    .removeDuplicates()
                    .sink(receiveValue: handleEvent)
            }
        }
    }

    private func cleanupSubscription() {
        if let service = network.eventServiceForDirect {
            service.subscriptionIdForPrivateMessages.map { network.relayPool?.closeSubscription(with: $0) }
        }
    }

    private func handleEvent(event: NostrEvent) {
        if let message = processEventIntoMessage(event: event) {
            if network.eventServiceForDirect?.fetchingStoredEvents ?? false {
                messageHandler.messages.insert(message, at: 0)
            } else {
                messageHandler.messages.append(message)
            }
        }
    }

    private func publishEvent(text: String) {
        guard let account = keychainForNostr.account,
              let recipientPublicKey = PublicKey(npub: user.npub) else { return }

        do {
            let contentStructure = ContentStructure(content: text, kind: .message)
            let jsonData = try JSONEncoder().encode(contentStructure)
            let content = String(data: jsonData, encoding: .utf8) ?? text

            let directMessage = try legacyEncryptedDirectMessage(
                withContent: content,
                toRecipient: recipientPublicKey,
                signedBy: account
            )
            network.relayPool?.publishEvent(directMessage)
        } catch {
            print(error.localizedDescription)
        }
    }

    var currentFilter: Filter? {
        guard let account = keychainForNostr.account,
              let recipientHex = PublicKey(npub: user.npub)?.hex else { return nil }
        
        let authors = [recipientHex, account.publicKey.hex]
        return Filter(authors: authors, kinds: [4], tags: ["p": authors], limit: 64)
    }

    func processEventIntoMessage(event: NostrEvent) -> MessageType? {
        guard let myKeypair = keychainForNostr.account,
              let recipientPublicKey = PublicKey(npub: user.npub) else { return nil }

        do {
            let decryptedText = try legacyDecrypt(
                encryptedContent: event.content,
                privateKey: myKeypair.privateKey,
                publicKey: recipientPublicKey
            )
            let decryptedEvent = NostrEvent.Builder(nostrEvent: event)
                .content(decryptedText)
                .build(pubkey: event.pubkey)

            return MessageHelper.parseEventIntoMessage(event: decryptedEvent, account: myKeypair)
        } catch {
            print("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - UI
private extension DirectMessage {
    private var backButton: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.left")
            }
            Button(action: {}) {
                HStack {
                    Image("user-skatepay")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatName()).fontWeight(.semibold).font(.headline)
                        Text(connected ? "online" : "offline").font(.footnote).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {}) {
                Image(systemName: "network").foregroundColor(.blue)
            }
            Button(action: { isShowingCameraView = true }) {
                Image(systemName: "camera.on.rectangle.fill").foregroundColor(.blue)
            }
        }
    }

    private func openChannelInvite() {
        guard let channelId = selectedChannelId else { return }

        navigation.joinChannel(channelId: channelId)
    }

    private func handleVideoTap(message: MessageType) {
        if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
            let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
            videoURL = URL(string: videoURLString)
            isShowingVideoPlayer.toggle()
        }
    }
}
#Preview {
    DirectMessage(user: AppData().users[0])
}
