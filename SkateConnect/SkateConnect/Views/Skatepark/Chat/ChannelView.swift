//
//  ChannelView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import os
import Combine
import ConnectFramework
import CoreLocation
import CryptoKit
import Foundation
import MessageKit
import NostrSDK
import SolanaSwift
import SwiftData
import SwiftUI
import UIKit

struct ChannelView: View {
    let log = OSLog(subsystem: "SkateConnect", category: "ChannelVIew")

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var eventBus: EventBus
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var stateManager: StateManager
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var walletManager: WalletManager
    
    @StateObject private var eventPublisher = ChannelEventPublisher()
    
    @StateObject private var eventListenerForMessages = ChannelMessageListener()
    @StateObject private var eventListenerForMetadata = ChannelMetadataListener()

    // Credentials
    let keychainForNostr = NostrKeychainStorage()

    @State var channelId: String
    @State var type = ChannelType.outbound
    
    // Base
    @State private var selectedChannelId: String? = nil
    
    // Toolbox
    @State private var isShowingToolBoxView = false
    
    @State private var showingMediaActionSheet = false
    @State private var selectedMediaURL: URL?

    // Invite
    @State private var showingInviteActionSheet = false

    @State private var selectedInviteString: String? = nil
    
    // Invoice
    @State private var showingInvoiceActionSheet = false
    @State private var showingTransactionAlert = false
    @State private var showingRefusalAlert = false

    @State private var selectedInvoiceString: String? = nil
    @State private var selectedInvoice: Invoice? = nil

    // Invoice - Asset Transfer
    @State private var transactionId: String = ""
    @State private var alertMessage: String = ""
    
    // View State
    @State private var shouldScrollToBottom = true

    var landmarks: [Landmark] = AppData().landmarks
    
    private var editChannelView: some View {
        Group {
            if let channel = self.eventListenerForMetadata.channel {
                EditChannel(channel: channel)
                    .environmentObject(dataManager)
                    .environmentObject(navigation)
            } else {
                // Fallback view if channel is nil (optional)
                EmptyView()
            }
        }
    }
    
    var readonly: Bool {
        if let channel = network.getChannel(for: channelId) {
            guard let creationEvent = channel.creationEvent else { return false }
            
            let isCreator = dataManager.isMe(pubkey: creationEvent.pubkey)
            
            if isCreator {
                return false
            } else {
                return Constants.CHANNELS.FAQ == channelId
            }
        } else {
            return Constants.CHANNELS.FAQ == channelId
        }
    }
    
    var body: some View {
        VStack {
            ChatView(
                currentUser: getCurrentUser(),
                readonly: readonly,
                messages: $eventListenerForMessages.messages,
                shouldScrollToBottom: $shouldScrollToBottom,
                onTapAvatar: { senderId in
                    navigation.path.append(NavigationPathType.userDetail(npub: senderId))
                    shouldScrollToBottom = false
                },
                onTapVideo: { message in
                    if case MessageKind.video(let media) = message.kind, let imageUrl = media.url {
                        let videoURLString = imageUrl.absoluteString.replacingOccurrences(of: ".jpg", with: ".mov")
                        self.selectedMediaURL = URL(string: videoURLString)
                        showingMediaActionSheet = true
                    }
                    shouldScrollToBottom = false
                },
                onTapLink: { action, channelId, dataString, isOwner in
                    if action == .invite {
                        selectedInviteString = dataString
                        showingInviteActionSheet = true
                    }
                    
                    if action == .invoice {
                        if isOwner {
                            showingRefusalAlert = true
                        } else {
                            setSelectedInvoiceString(dataString)
                            showingInvoiceActionSheet = true
                        }
                    }
                    
                    selectedChannelId = channelId
                    shouldScrollToBottom = false
                },
                onSend: { text in
                    network.publishChannelEvent(channelId: channelId, content: text)
                    shouldScrollToBottom = true
                }
            )
            .navigationBarBackButtonHidden()
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                editChannelView
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: {
                            navigation.channelId = nil
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                        }
                        
                        Button(action: {
                            navigation.isShowingEditChannel.toggle()
                        }) {
                             if let channel = eventListenerForMetadata.channel {
                                if let channelId = channel.creationEvent?.id, let landmark = findLandmark(channelId) {
                                    HStack {
                                        landmark.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 35, height: 35)
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(landmark.name)
                                                .fontWeight(.semibold)
                                                .font(.headline)
                                        }
                                    }
                                } else {
                                    if let title = getTitle(channel: channel) {
                                        Text(title)
                                            .fontWeight(.semibold)
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            self.isShowingToolBoxView.toggle()
                        }) {
                            Image(systemName: "menucard.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            navigation.channelId = channelId
                            navigation.path.append(NavigationPathType.camera)
                        }) {
                            Image(systemName: "camera.on.rectangle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingToolBoxView) {
                ToolBoxView(channelId: channelId)
                    .environmentObject(debugManager)
                    .environmentObject(navigation)
                    .environmentObject(uploadManager)
                    .environmentObject(walletManager)
                    .presentationDetents([.medium])
            }
            .onChange(of: eventListenerForMessages.receivedEOSE) {
                if eventListenerForMessages.receivedEOSE {
                    shouldScrollToBottom = true
                }
            }
            .onChange(of: eventListenerForMessages.timestamp) {
                if eventListenerForMessages.receivedEOSE {
                    shouldScrollToBottom = true
                }
            }
            .onAppear {
                if let account = keychainForNostr.account {
                    self.eventListenerForMetadata.setChannelType(type)
                    self.eventListenerForMetadata.setChannelId(channelId)
                    self.eventListenerForMetadata.reset()
                    
                    self.eventPublisher.subscribeToMetadataFor(channelId)

                    if (self.eventListenerForMessages.receivedEOSE) {
                        shouldScrollToBottom = false
                        return
                    }
                    
                    shouldScrollToBottom = true

                    self.eventListenerForMessages.setChannelId(channelId)
                    self.eventListenerForMessages.setDependencies(
                        dataManager: dataManager,
                        debugManager: debugManager,
                        account: account
                    )
                    self.eventListenerForMessages.reset()

                    self.eventPublisher.subscribeToMessagesFor(channelId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .uploadImage)) { notification in
                if let assetURL = notification.userInfo?["assetURL"] as? String {
                    network.publishChannelEvent(channelId: channelId,
                                                kind: .photo,
                                                content: assetURL
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .muteUser)) { _ in
                if let account = keychainForNostr.account {
                    self.eventListenerForMetadata.setChannelId(channelId)
                    
                    self.eventPublisher.subscribeToMetadataFor(channelId) 

                    self.eventListenerForMessages.setChannelId(channelId)
                    self.eventListenerForMessages.setDependencies(
                        dataManager: dataManager,
                        debugManager: debugManager,
                        account: account
                    )
                    self.eventListenerForMessages.reset()
                    
                    self.eventPublisher.subscribeToMessagesFor(channelId)
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .modifier(IgnoresSafeArea())
        }
        .confirmationDialog("Media Options", isPresented: $showingMediaActionSheet, titleVisibility: .visible) {
            Button("Play") {
                if let videoURL = selectedMediaURL {
                    navigation.path.append(NavigationPathType.videoPlayer(url: videoURL))
                }
            }
            Button("Download") {
                if let videoURL = selectedMediaURL {
                    downloadVideo(from: videoURL)
                }
            }
            Button("Share") {
                if let videoURL = selectedMediaURL {
                    MainHelper.shareVideo(videoURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Spot Invite", isPresented: $showingInviteActionSheet, titleVisibility: .visible) {
            Button("Accept") {
                openChannelInvite()
            }
            Button("Copy") {
                if let inviteString = selectedInviteString {
                    UIPasteboard.general.string = "channel_invite:\(inviteString)"
                } else {
                    UIPasteboard.general.string = "channel_invite:NOT_AVAILABLE"
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        // Invoice
        .confirmationDialog("Invoice", isPresented: $showingInvoiceActionSheet, titleVisibility: .visible) {
            Button("Pay") {
                openWallet()
            }
            Button("Copy Address") {
                if let invoice = selectedInvoice {
                    UIPasteboard.general.string = invoice.address
                } else {
                    UIPasteboard.general.string = "invoice:NOT_AVAILABLE"
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Can't pay your own invoice.", isPresented: $showingRefusalAlert, titleVisibility: .visible) {
            Button("Okay", role: .cancel) {
                showingRefusalAlert = false
            }
        }
        .alert(isPresented: $showingTransactionAlert) {
            Alert(
                title: Text(transactionId.isEmpty ? "Error" : "Success"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    showingTransactionAlert = true
                    
                    if (!transactionId.isEmpty) {
                        NotificationCenter.default.post(
                            name: .publishChannelEvent,
                            object: nil,
                            userInfo: [
                                "channelId": channelId,
                                "content": "🧾 Receipt: https://solscan.io/tx/\(transactionId)?cluster=\(walletManager.network)",
                                "kind": Kind.message
                            ]
                        )
                    }
                    
                    transactionId = ""
                }
            )
        }
    }
    
    // MARK: Blacklist
    func findLandmark(_ eventId: String) -> Landmark? {
        return landmarks.first { $0.eventId == eventId }
    }
    
    private func openChannelInvite() {
        guard let channelId = selectedChannelId else { return }

        navigation.joinChannel(channelId: channelId)
    }

    private func downloadVideo(from url: URL) {
        print("Downloading video from \(url)")
    }
}

// MARK: - Invoice

private extension ChannelView {
    func setSelectedInvoiceString(_ invoiceString: String) {
        selectedInvoiceString = invoiceString
        selectedInvoice = Invoice.decodeInvoiceFromString(invoiceString)
    }
    
    private func openWallet() {
        guard let invoice = selectedInvoice else { return }

        // Parse network and mintAddress from metadata
        let parsed = MessageHelper.parseNetworkAndMint(from: invoice)
        guard let (targetNetwork, mintAddress) = parsed else {
            print("❌ Failed to parse network and mintAddress from invoice")
            return
        }

        guard let amountDecimal = Double(invoice.amount) else {
            print("❌ Invalid amount format: \(invoice.amount)")
            return
        }

        // 🔄 Switch network if needed
        if walletManager.network != targetNetwork {
            walletManager.network = targetNetwork
            walletManager.updateApiClient()
            walletManager.refreshAliases()
        }

        // ⏳ Fetch latest wallet data before proceeding
        walletManager.fetchAccountDetails { result in
            switch result {
            case .success:
                processInvoicePayment(invoice: invoice, mintAddress: mintAddress, amountDecimal: amountDecimal)
            case .failure(let error):
                alertMessage = "❌ Failed to fetch wallet data: \(error)"
                showingTransactionAlert = true
            }
        }
    }
    
    private func processInvoicePayment(invoice: Invoice, mintAddress: String, amountDecimal: Double) {
        let transferType: TransferType
        let amountUInt64: UInt64

        if mintAddress == "SOL_NATIVE" {
            transferType = .sol
            amountUInt64 = UInt64(amountDecimal * 1_000_000_000)
        } else {
            guard let tokenAccount = walletManager.accounts.first(where: { $0.token.mintAddress == mintAddress }) else {
                alertMessage = "❌ No token account for mint: \(mintAddress)"
                showingTransactionAlert = true
                return
            }

            let factor = pow(10.0, Double(tokenAccount.decimals))
            amountUInt64 = UInt64(amountDecimal * factor)
            transferType = .token(tokenAccount)
        }

        Task {
            let result = await walletManager.sendAsset(type: transferType, to: invoice.address, amount: amountUInt64)

            await MainActor.run {
                switch result {
                case .success(let txId):
                    transactionId = txId
                    alertMessage = "✅ Invoice paid, txn ID: \(txId.prefix(8))"
                case .failure(let error):
                    alertMessage = "❌ Failed to pay invoice: \(error.localizedDescription)"
                }
                showingTransactionAlert = true
            }
        }
    }
}

// MARK: - Helpers
private extension ChannelView {
    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
    }
    
    func getTitle(channel: Channel) -> String? {
        guard let creationEvent = channel.creationEvent else {
            return nil 
        }

        let baseTitle = channel.metadata?.name ?? channel.name
        let isCreator = dataManager.isMe(pubkey: creationEvent.pubkey)
        let readOnlyIndicator = readonly ? "ℹ️ " : ""
        let creatorIndicator = isCreator ? " 👑" : ""

        return "\(readOnlyIndicator)\(baseTitle)\(creatorIndicator)"
    }
}

struct IgnoresSafeArea: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 14.0, *) {
            content.ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            content
        }
    }
}

#Preview {
    ChannelView(channelId: "")
}

