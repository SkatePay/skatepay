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


enum ActiveAlert: Identifiable {
    case transaction(title: String, message: String, txId: String?)
    case downloading
    case report(npub: String)
    case park
    
    var id: String {
        switch self {
        case .transaction(let title, _, _):
            return "transaction_\(title)"
        case .downloading:
            return "downloading"
        case .report(let npub):
            return "report_\(npub)"
        case .park:
            return "park"
        }
    }
}

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
    @EnvironmentObject var videoDownloader: VideoDownloader
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
    
    // Action Sheets
    @State private var showingInviteActionSheet = false
    @State private var showingInvoiceActionSheet = false
    @State private var showingMessageActionSheet = false
    
    @State private var selectedMessageId: String? = nil
    
    // Toolbox
    @State private var isShowingToolBoxView = false
    
    // Invite
    @State private var selectedInviteString: String? = nil
    
    // Invoice
    @State private var selectedInvoiceString: String? = nil
    @State private var selectedInvoice: Invoice? = nil
    @State private var showingRefusalAlert = false
    
    @State private var activeAlert: ActiveAlert? = nil
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
                        guard let videoURL = URL(string: videoURLString) else { return }
                        
                        navigation.path.append(NavigationPathType.videoPlayer(url: videoURL))
                    }
                    
                    if case MessageKind.photo(_) = message.kind {
                        showingMessageActionSheet = true
                        selectedMessageId = message.messageId
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
                onTapMessage: { message in
                    print(message)
                    showingMessageActionSheet = true
                    selectedMessageId = message.messageId
                },
                onSend: { text in
                    network.publishChannelEvent(channelId: channelId, text: text)
                    shouldScrollToBottom = true
                }
            )
            .navigationBarBackButtonHidden()
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
            .sheet(isPresented: $navigation.isShowingEditChannel) {
                editChannelView
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
                guard let account = keychainForNostr.account else {
                    os_log("🔥 can't get account", log: log, type: .error)
                    return
                }
                
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
            .onReceive(NotificationCenter.default.publisher(for: UploadNotification.Image)) { notification in
                // Check if source is "toolbox"
                guard let source = notification.userInfo?["source"] as? String,
                      source == SourceType.toolbox.rawValue else {
                    os_log("🛑 Ignoring notification: source is not toolbox", log: log, type: .debug)
                    return
                }
                
                // Proceed with processing the assetURL
                guard let assetURL = notification.userInfo?["assetURL"] as? String else {
                    os_log("⚠️ Missing assetURL in uploadImage notification", log: log, type: .error)
                    return
                }
                
                network.publishChannelEvent(channelId: channelId,
                                            kind: .photo,
                                            text: assetURL)
                os_log("✅ Published channel event with assetURL: %{public}@", log: log, type: .info, assetURL)
            }
            .onReceive(NotificationCenter.default.publisher(for: .muteUser)) { _ in
                guard let account = keychainForNostr.account else { return }
                
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
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .modifier(IgnoresSafeArea())
        }
        .alert(item: $activeAlert) { alertType in // alertType is the non-nil ActiveAlert value
            switch alertType {
            case .transaction(let title, let message, let txId):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        // Action on dismiss specific to transaction alert
                        print("Transaction Alert OK tapped")
                        if let confirmedTxId = txId, !confirmedTxId.isEmpty {
                            // Post notification only if txId was valid
                            NotificationCenter.default.post(
                                name: .publishChannelEvent,
                                object: nil,
                                userInfo: [
                                    "channelId": channelId,
                                    "content": "🧾 Receipt: https://solscan.io/tx/\(confirmedTxId)?cluster=\(walletManager.network)",
                                    "kind": Kind.message // Ensure Kind.message is defined
                                ]
                            )
                        }
                    }
                )
            case .downloading:
                return Alert(
                    title: Text("Downloading..."),
                    // Add message if desired
                    dismissButton: .default(Text("OK")) {
                        // Action on dismiss specific to download alert (if any)
                        print("Download Alert OK tapped")
                    }
                )
            case .report(npub: _):
                return Alert(title: Text(""))
            case .park:
                return Alert(title: Text(""))
            }
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
        .confirmationDialog("Message Actions", isPresented: $showingMessageActionSheet, titleVisibility: .visible) {
            if let messageId = selectedMessageId,
               let event = eventListenerForMessages.events[messageId] {
                
                if dataManager.isMe(pubkey: event.pubkey) {
                    Button("Delete", role: .destructive) {  // Note: .destructive for delete
                        deleteEvent(event)
                    }
                } else {
                    Button("Mute User", role: .destructive) {  // Muting is also destructive
                        print("muting user")
                        // Add actual mute logic here
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    showingMessageActionSheet = false
                }
            }
        }
        .confirmationDialog("Can't pay your own invoice.", isPresented: $showingRefusalAlert, titleVisibility: .visible) {
            Button("Okay", role: .cancel) {
                showingRefusalAlert = false
            }
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
        
        videoDownloader.downloadVideo(from: url) { loading, _ in
            if (loading) {
                self.activeAlert = .downloading
            }
        }
    }
    
    private func deleteEvent(_ event: NostrEvent) {
        network.deleteEvent(event)
        refresh()
    }
    
    // This method only works properly cleanup after deletion.
    private func refresh() {
        guard let account = keychainForNostr.account else { return }
        
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
                self.activeAlert = .transaction(title: "Error", message: alertMessage, txId: "")
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
                self.activeAlert = .transaction(title: "Error", message: alertMessage, txId: "")
                return
            }
            
            let factor = pow(10.0, Double(tokenAccount.decimals))
            amountUInt64 = UInt64(amountDecimal * factor)
            transferType = .token(tokenAccount)
        }
        
        Task {
            let result = await walletManager.sendAsset(type: transferType, to: invoice.address, amount: amountUInt64)
           
            DispatchQueue.main.async {
                var alertTitle = ""
                var alertMsg = ""
                var finalTxId: String? = nil // Store txId specifically for the alert case

                switch result {
                case .success(let txId):
                    alertTitle = "Success"
                    alertMsg = "✅ Invoice paid, txn ID: \(txId.prefix(8))"
                    finalTxId = txId
                case .failure(let error):
                     alertTitle = "Error"
                     alertMsg = "❌ Failed to pay invoice: \(error.localizedDescription)"
                }

                self.activeAlert = .transaction(title: alertTitle, message: alertMsg, txId: finalTxId)
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
        content.ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
