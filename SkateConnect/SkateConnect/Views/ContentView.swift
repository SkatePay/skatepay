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

enum Tab {
    case lobby
    case map
    case wallet
    case debug
    case settings
}

class ContentViewModel: ObservableObject {
    @Published var fetchingStoredEvents: Bool = true
    var mark: Mark?
}

struct ContentView: View {
    @Environment(
        \.modelContext
    ) private var context
    
    @EnvironmentObject private var apiService: API
    @EnvironmentObject private var channelViewManager: ChannelViewManager
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var eulaManager: EULAManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var lobby: Lobby
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var store = HostStore()
    @State private var incomingMessagesCount = 0
    
    let keychainForNostr = NostrKeychainStorage()
    
    var body: some View {
        TabView(
            selection: $navigation.tab
        ) {
            LobbyView()
                .tabItem {
                    Label(
                        "Lobby",
                        systemImage: "star"
                    )
                }
                .onAppear {
                    navigation.activeView = .lobby
                }
                .environmentObject(dataManager)
                .environmentObject(lobby)
                .environmentObject(navigation)
                .environmentObject(network)
                .badge(
                    incomingMessagesCount > 0 ? incomingMessagesCount : 0
                )
                .tag(
                    Tab.lobby
                )
            
            SkateView()
                .tabItem {
                    Label(
                        "Map",
                        systemImage: "map"
                    )
                }
                .onAppear {
                    navigation.activeView = .map
                }
                .environmentObject(apiService)
                .environmentObject(channelViewManager)
                .environmentObject(dataManager)
                .environmentObject(lobby)
                .environmentObject(locationManager)
                .environmentObject(navigation)
                .environmentObject(network)
                .environmentObject(stateManager)
                .tag(
                    Tab.map
                )
            
            if (
                hasWallet()
            ) {
                WalletView(
                    host: $store.host
                ) {
                    Task {
                        await saveHost()
                    }
                }
                .tabItem {
                    Label(
                        "Wallet",
                        systemImage: "creditcard.and.123"
                    )
                }
                .tag(
                    Tab.wallet
                )
            } else {
                SettingsView(
                    host: $store.host
                )
                .tabItem {
                    Label(
                        "Settings",
                        systemImage: "gearshape"
                    )
                }
                .onAppear {
                    navigation.activeView = .settings
                }
                .environmentObject(eulaManager)
                .environmentObject(lobby)
                .environmentObject(navigation)
                .environmentObject(network)
                .tag(
                    Tab.settings
                )
            }
        }
        .fullScreenCover(
            isPresented: $navigation.isShowingUserDetail
        ) {
            NavigationView {
                if let npub = navigation.selectedUserNpub {
                    let user = getUser(
                        npub: npub
                    )
                    UserDetail(
                        user: user
                    )
                    .environmentObject(navigation)
                    .environmentObject(network)
                    .navigationBarItems(leading:
                                            Button(action: {
                        navigation.isShowingUserDetail = false
                    }) {
                        HStack {
                            Image(
                                systemName: "arrow.left"
                            )
                            Text(
                                "Exit"
                            )
                            Spacer()
                        }
                    })
                }
            }
        }
        .onAppear {
            network.reconnectRelaysIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .receivedDirectMessage
            )
        ) { notification in
            handleDirectMessage(
                notification
            )
        }
        .task {
            await insertDefaultFriend()
        }
        .environmentObject(
            viewModel
        )
        .environmentObject(
            store
        )
    }
    
    // MARK: - Helper Functions
    
    private func handleDirectMessage(
        _ notification: Notification
    ) {
        if let event = notification.object as? NostrEvent {
            lobby.dms.insert(
                event
            )
            incomingMessagesCount = lobby.dms.count
        }
    }
    
    private func saveHost() async {
        do {
            try await store.save(
                host: store.host
            )
        } catch {
            fatalError(
                error.localizedDescription
            )
        }
    }
    
    private func insertDefaultFriend() async {
        context.insert(
            Friend(
                name: AppData().users[0].name,
                birthday: Date.now,
                npub: AppData().getSupport().npub,
                solanaAddress: AppData().users[0].solanaAddress,
                note: "Support Team"
            )
        )
    }
}

#Preview {
    ContentView().environment(
        AppData()
    )
}
