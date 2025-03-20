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
    @State private var showingTransactionAlert = false
    @State private var showingRefusalAlert = false

    @State private var selectedInvoiceString: String? = nil
    @State private var selectedInvoice: Invoice? = nil
    
    // Invoice - Asset Transfer
    @State private var transactionId: String = ""
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
            messages: $eventListenerForMessages.messages,
            shouldScrollToBottom: $shouldScrollToBottom,
            onTapAvatar: {_ in 
                print("Avatar tapped")
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
            onSend: { text in
                guard let publicKey = PublicKey(npub: user.npub) else { return }
                network.publishDMEvent(publicKey: publicKey, content: text)
                shouldScrollToBottom = true
            }
        )
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: backButton, trailing: actionButtons)
        .sheet(isPresented: $isShowingToolBoxView) {
            ToolBoxView()
                .environmentObject(debugManager)
                .environmentObject(navigation)
                .environmentObject(uploadManager)
                .environmentObject(walletManager)
                .presentationDetents([.medium])
                .onAppear {
                    navigation.user = user
                }
        }
        .actionSheet(isPresented: $showingInviteActionSheet) {
            ActionSheet(
                title: Text("Confirmation"),
                message: Text("Are you sure you want to join this channel?"),
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
        .modifier(IgnoresSafeArea())
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
                    if (!transactionId.isEmpty) {
                        NotificationCenter.default.post(
                            name: .publishDMEvent,
                            object: nil,
                            userInfo: [
                                "npub": user.npub,
                                "content": "🧾 Receipt: https://solscan.io/tx/\(transactionId)?cluster=\(walletManager.network)",
                                "kind": Kind.message
                            ]
                        )
                    }
                    
                    transactionId = ""
                    showingTransactionAlert = true
                }
            )
        }
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

// MARK: - UI
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
#Preview {
    DMView(user: AppData().users[0])
}
