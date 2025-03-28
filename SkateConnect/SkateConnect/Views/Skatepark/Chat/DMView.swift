//
//  DMView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import os
import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import SolanaSwift
import SwiftUI
import UIKit

struct DMView: View, LegacyDirectMessageEncrypting, EventCreating {
    let log = OSLog(subsystem: "SkateConnect", category: "DMView")
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var walletManager: WalletManager
    
    @StateObject private var eventPublisher = DMEventPublisher()
    
    @StateObject private var eventListenerForMessages = DMMessageListener()
    
    // Credentials
    private let keychainForNostr = NostrKeychainStorage()
    
    private var user: User
    private var message: String
    
    // Sheets
    @State private var isShowingCameraView = false
    @State private var isShowingVideoPlayer = false
    
    // Toolbox
    @State private var isShowingToolBoxView = false
    
    @State private var showAlertForReporting = false
    @State private var showAlertForAddingPark = false
    
    // Action State
    @State private var selectedChannelId: String?
    @State private var selectedMediaURL: URL?
    
    // Invite
    @State private var selectedInviteString: String? = nil
    
    @State private var showingInviteActionSheet = false
    
    // Invoice
    @State private var showingInvoiceActionSheet = false
    @State private var showingRefusalAlert = false
    
    @State private var selectedInvoiceString: String? = nil
    @State private var selectedInvoice: Invoice? = nil
    
    // Invoice - Asset Transfer
    @State private var activeAlert: ActiveAlert? = nil
    @State private var alertMessage: String = ""
    
    // View State
    @State private var shouldScrollToBottom = true
    
    init(user: User, message: String = "") {
        self.user = user
        self.message = message
    }
    
    var body: some View {
        ChatView(
            currentUser: getCurrentUser(),
            readonly: false,
            messages: $eventListenerForMessages.messages,
            shouldScrollToBottom: $shouldScrollToBottom,
            onTapAvatar: {_ in
                shouldScrollToBottom = false
            },
            onTapVideo: handleVideoTap,
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
            },
            onSend: { text in
                guard let publicKey = PublicKey(npub: user.npub) else { return }
                network.publishDMEvent(publicKey: publicKey, text: text)
                shouldScrollToBottom = true
            }
        )
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: backButton, trailing: actionButtons)
        .sheet(isPresented: $isShowingToolBoxView) {
            ToolBoxView(user: user)
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
            if (self.eventListenerForMessages.receivedEOSE) {
                return
            }
            
            shouldScrollToBottom = true
            
            if let account = keychainForNostr.account {
                
                guard let publicKey = PublicKey(npub: user.npub) else {
                    os_log("🔥 can't convert npub", log: log, type: .error)
                    return
                }
                
                self.eventListenerForMessages.setPublicKey(publicKey)
                
                self.eventListenerForMessages.setDependencies(
                    dataManager: dataManager,
                    debugManager: debugManager,
                    account: account
                )
                
                self.eventListenerForMessages.reset()
                
                self.eventPublisher.subscribeToUserWithPublicKey(publicKey)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UploadNotification.Image)) { notification in
            if let assetURL = notification.userInfo?["assetURL"] as? String {
                if let npub = notification.userInfo?["npub"] as? String {
                    guard let publicKey = PublicKey(npub: npub) else { return }
                    
                    network.publishDMEvent(publicKey: publicKey, kind: .photo, text: assetURL)
                } else {
                    os_log("⚠️ Warning: Received uploadImage notification without npub.", log: log, type: .error)
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .modifier(IgnoresSafeArea())
        // Action Sheets
        .actionSheet(isPresented: $showingInviteActionSheet) {
            ActionSheet(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to go to this spot?"),
                buttons: [
                    .default(Text("Yes")) {
                        openChannelInvite()
                    },
                    .default(Text("Copy Invite")) {
                        
                        showingInviteActionSheet = false
                        
                        if let inviteString = selectedInviteString {
                            UIPasteboard.general.string = "channel_invite:\(inviteString)"
                        } else {
                            UIPasteboard.general.string = "channel_invite:NOT_AVAILABLE"
                        }
                    },
                    .cancel(Text("Maybe Later")) {
                        showingInviteActionSheet = false
                    }
                ]
            )
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
        .confirmationDialog("Can't pay your own invoice.", isPresented: $showingRefusalAlert, titleVisibility: .visible) {
            Button("Okay", role: .cancel) {
                showingRefusalAlert = false
            }
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
                            NotificationCenter.default.post(
                                name: .publishDMEvent,
                                object: nil,
                                userInfo: [
                                    "npub": user.npub,
                                    "content": "🧾 Receipt: https://solscan.io/tx/\(confirmedTxId)?cluster=\(walletManager.network)",
                                    "kind": Kind.message
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
            }
        }
    }
}

// MARK: - UI Components
private extension DMView {
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
            HStack(spacing: 16) {
                Button(action: {
                    self.isShowingToolBoxView.toggle()
                }) {
                    Image(systemName: "menucard.fill")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    //                    navigation.path.append(NavigationPathType.camera)
                }) {
                    Image(systemName: "camera.on.rectangle.fill")
                        .foregroundColor(.blue)
                }
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
            selectedMediaURL = URL(string: videoURLString)
            isShowingVideoPlayer.toggle()
        }
        
        shouldScrollToBottom = false
    }
}

// MARK: - Invoice
private extension DMView {
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
        
        // ⏳ Fetch latest wallet data
        walletManager.fetchAccountDetails { result in
            switch result {
            case .success:
                processInvoicePayment(invoice: invoice, mintAddress: mintAddress, amountDecimal: amountDecimal)
            case .failure(let error):
                self.alertMessage = "❌ Failed to fetch wallet data: \(error)"
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
private extension DMView {
    private var connected: Bool {
        network.relayPool?.relays.contains { $0.url == URL(string: user.relayUrl) } ?? false
    }
    
    func formatName() -> String {
        dataManager.findFriend(user.npub)?.name ?? MainHelper.friendlyKey(npub: user.npub)
    }
    
    func getCurrentUser() -> MockUser {
        if let account = keychainForNostr.account {
            return MockUser(senderId: account.publicKey.npub, displayName: "You")
        }
        return MockUser(senderId: "000002", displayName: "You")
    }
}
