//
//  ContentView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import ConnectFramework
import Combine
import CoreLocation
import NostrSDK
import SwiftData
import SwiftUI
import UIKit

struct TabButton: View {
    let tab: Tab
    let label: String
    let systemImage: String
    @Binding var selectedTab: Tab
    var count: Int = 0  // New count property

    var body: some View {
        Button(action: {
            selectedTab = tab
        }) {
            ZStack {
                VStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 20))
                    Text(label)
                        .font(.caption)
                }
                .foregroundColor(selectedTab == tab ? .blue : .gray)
                .frame(maxWidth: .infinity)

                // Badge (only shown if count > 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 15, y: -10)
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var apiService: API
    @EnvironmentObject private var channelViewManager: ChannelViewManager
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var debugManager: DebugManager
    @EnvironmentObject private var eulaManager: EULAManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var lobby: Lobby
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    @EnvironmentObject private var uploadManager: UploadManager
    @EnvironmentObject private var videoDowloader: VideoDownloader
    @EnvironmentObject private var walletManager: WalletManager
    
    @StateObject private var store = HostStore()

    @State private var incomingMessagesCount = 0
        
    var lobbyUnreadCount: Int {
        return lobby.unreadCounts.values.reduce(0, +)
    }
    
    var body: some View {
        NavigationStack(path: $navigation.path) {
            VStack(spacing: 0) {
                switch navigation.tab {
                case .lobby:
                    LobbyView()
                        .environmentObject(dataManager)
                        .environmentObject(lobby)
                        .environmentObject(navigation)
                        .environmentObject(network)
                case .map:
                    SkateView()
                        .environmentObject(apiService)
                        .environmentObject(channelViewManager)
                        .environmentObject(dataManager)
                        .environmentObject(lobby)
                        .environmentObject(locationManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(stateManager)
                case .wallet:
                    if shouldShowWalletView {
                        WalletView {
                            Task {
                                await saveHost()
                            }
                        }
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .environmentObject(walletManager)
                        .navigationBarTitle("🪪 Wallet")

                    } else {
                        // Show a placeholder or empty view if the wallet shouldn't be shown
                        Text("Wallet not available")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                case .settings:
                    SettingsView(host: $store.host)
                        .environmentObject(dataManager)
                        .environmentObject(debugManager)
                        .environmentObject(eulaManager)
                        .environmentObject(lobby)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .navigationBarTitle("🛠️ Settings")

                }
                
                // Custom Tab Bar
                HStack {
                    // Lobby Tab
                    TabButton(
                        tab: .lobby,
                        label: "Lobby",
                        systemImage: "star",
                        selectedTab: $navigation.tab,
                        count: lobbyUnreadCount
                    )
                    
                    // Map Tab
                    TabButton(
                        tab: .map,
                        label: "Map",
                        systemImage: "map",
                        selectedTab: $navigation.tab
                    )
                    
                    // Settings Tab
                    TabButton(
                        tab: .settings,
                        label: "Settings",
                        systemImage: "gearshape",
                        selectedTab: $navigation.tab
                    )
                    
                    // Wallet Tab (conditionally shown)
                    if shouldShowWalletView {
                        TabButton(
                            tab: .wallet,
                            label: "Wallet",
                            systemImage: "creditcard.and.123",
                            selectedTab: $navigation.tab
                        )
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            }        
            .navigationDestination(for: NavigationPathType.self) { path in
                switch path {
                case .addressBook:
                    AddressBook()
                        .environmentObject(dataManager)
                        .environmentObject(lobby)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .navigationTitle("Spots")

                case .barcodeScanner:
                    BarcodeScanner()
                        .environmentObject(navigation)
               
                case .birthday:
                    BirthdayView()
                        .environmentObject(navigation)
                
                case .camera:
                    CameraView()
                        .environmentObject(navigation)
                        .environmentObject(uploadManager)
                    
                case .channel(let channelId, let invite):
                    ChannelView(channelId: channelId, type: invite ? .inbound : .outbound)
                        .environmentObject(dataManager)
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(stateManager)
                        .environmentObject(uploadManager)
                        .environmentObject(videoDowloader)
                        .environmentObject(walletManager)
                        .onDisappear {
                            locationManager.panMapToCachedCoordinate()
                        }
                
                case .connectRelay:
                    ConnectRelay()
                        .environmentObject(network)
                    
                case .contacts:
                    Contacts()
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .navigationTitle("Friends")
                
                case .createChannel:
                    CreateChannel()
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(stateManager)
                    
                case .createMessage:
                    CreateMessage()
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .navigationTitle("Direct Message")
                   
                case .deckDetails(let image, let fileURL):
                    DeckDetailsView(deckImage: image, fileURL: fileURL)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(uploadManager)
                    
                case .deckTracker:
                    DeckTrackerView()
                        .environmentObject(network)
                    
                case .directMessage(user: let user):
                    DMView(user: user)
                        .environmentObject(dataManager)
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(uploadManager)
                        .environmentObject(walletManager)
                    
                case .filters:
                    Filters()
                        .navigationBarTitle("Filters")
                   
                case .importIdentity:
                    ImportIdentity()
                        .environmentObject(lobby)
                    
                case .importWallet:
                    ImportWallet()
                        .environmentObject(navigation)
                        .environmentObject(walletManager)
                    
                case .landmarkDirectory:
                    LandmarkDirectory()
                        .environmentObject(dataManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .navigationBarTitle("🏁 Skateparks")
                    
                case .reportUser(user: let user, message: let message):
                    DMView(user: user, message: message)
                        .environmentObject(dataManager)
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(uploadManager)
                        .environmentObject(walletManager)
                
                case .recoveryPhrase(let mnemonic):
                    RecoveryPhraseView(mnemonic: mnemonic)
                        .environmentObject(navigation)
                        .environmentObject(walletManager)
                    
                case .restoreData:
                    RestoreDataView()
                        .environmentObject(dataManager)
                        .environmentObject(navigation)
                        .environmentObject(walletManager)
                
                case .search:
                    SearchView()
                        .environmentObject(navigation)
                        .navigationBarTitle("🎯 Explore Network 🕸️")
                    
                case .userDetail(let npub):
                    let user = MainHelper.getUser(npub: npub, name: nil)
                    UserDetails(user: user)
                        .environmentObject(dataManager)
                        .environmentObject(debugManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                        .environmentObject(uploadManager)

                case .transferAsset(let transferType):
                    TransferAsset(transferType: transferType)
                        .environmentObject(walletManager)
                    
                case .videoPlayer(let url):
                    VideoPreviewView(url: url)
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .receivedDirectMessage)
        ) { notification in
            handleDirectMessage(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscribeToChannel)) { notification in
            if let channelId = notification.userInfo?["channelId"] as? String {
                if let spot = dataManager.findSpotsForChannelId(channelId).first {
                    navigation.coordinate = spot.locationCoordinate
                    locationManager.panMapToCachedCoordinate()
                }
                
                channelViewManager.openChannel(channelId: channelId, invite: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createdChannelForOutbound)) { notification in
            if let event = notification.object as? NostrEvent {
                if let lead = MainHelper.createLead(from: event) {
                    dataManager.saveSpotForLead(lead, pan: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createdChannelForInbound)) { notification in
            if let event = notification.object as? NostrEvent {
                if let lead = MainHelper.createLead(from: event) {
                    dataManager.saveSpotForLead(lead, note: "invite", pan: true)
                }
            }
        }
        .task {
            await insertDefaultFriend()
        }
        .environmentObject(store)
    }
    
    var shouldShowWalletView: Bool {
        hasWallet() || debugManager.hasEnabledDebug
    }
    
    @ViewBuilder
    var walletTab: some View {
        WalletView {
            Task {
                await saveHost()
            }
        }
        .environmentObject(debugManager)
        .environmentObject(navigation)
        .environmentObject(walletManager)
        .tabItem {
            Label("Wallet", systemImage: "creditcard.and.123")
        }
        .tag(Tab.wallet)
    }
    
    // MARK: - Helper Functions
    private func handleDirectMessage(_ notification: Notification) {
        if let event = notification.object as? NostrEvent {
            lobby.addEvent(event)
            lobby.dms.insert(event)
            incomingMessagesCount = lobby.dms.count
        }
    }
    
    private func saveHost() async {
        do {
            try await store.save(host: store.host)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func insertDefaultFriend() async {
       await dataManager.insertDefaultFriend()
    }
}

#Preview {
    ContentView().environment(
        AppData()
    )
}
