//
//  SettingsView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import Combine
import ConnectFramework
import CoreData
import NostrSDK
import SolanaSwift
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context

    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var eulaManager: EULAManager
    @EnvironmentObject var lobby: Lobby
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var walletManager: WalletManager
    
    @Binding var host: Host
    
    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    @State private var showingConfirmation = false
    @State private var showingQRCodeView = false
    
    @State private var imageTapCount = 0
    @State private var specialFeatureEnabled = false

    @State private var showCopyNotification = false
    
    let keychainForNostr = NostrKeychainStorage()
    
    var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        }
        return "Unknown Version"
    }
    
    var body: some View {
        VStack {
            Image("user-funkadelic")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .onTapGesture {
                    imageTapCount += 1
                    if imageTapCount == 3 {
                        specialFeatureEnabled = true
                        imageTapCount = 0
                        
                        if (debugManager.hasEnabledDebug) {
                            debugManager.resetDebug()
                        } else {
                            debugManager.enableDebug()
                        }
                    }
                }
            
            if debugManager.hasEnabledDebug {
                Text("🎉 Special Feature Unlocked! 🎉")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            Text(appVersion)
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            List {
                Section ("NOSTR") {
                    if let publicKey = keychainForNostr.account?.publicKey.npub {
                        Text("\(publicKey)")
                            .contextMenu {
                                if let npub = keychainForNostr.account?.publicKey.npub {
                                    Button(action: {
                                        self.npub = npub
                                        showingQRCodeView.toggle()
                                    }) {
                                        Text("Show QR")
                                    }
                                }
                                
                                if let npub = keychainForNostr.account?.publicKey.npub {
                                    Button(action: {
                                        UIPasteboard.general.string = npub
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy npub")
                                    }
                                }
                                
                                if let nsec = keychainForNostr.account?.privateKey.nsec {
                                    Button(action: {
                                        UIPasteboard.general.string = nsec
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy nsec")
                                    }
                                }
                                
                                if let phex = keychainForNostr.account?.publicKey.hex {
                                    Button(action: {
                                        UIPasteboard.general.string = phex
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy phex")
                                    }
                                }
                                
                                if let shex = keychainForNostr.account?.privateKey.hex {
                                    Button(action: {
                                        UIPasteboard.general.string = shex
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy shex")
                                    }
                                }
                            }
                    } else {
                        Text("Create new keys")
                    }
                    
                    NavigationLink {
                        ImportIdentity()
                            .environmentObject(lobby)
                    } label: {
                        Text("🔑 Keys")
                    }
                    NavigationLink {
                        ConnectRelay()
                            .environmentObject(network)
                    } label: {
                        Text("📡 Relays")
                    }
                }
                
                Button("💁 Get Help") {
                    Task {
                        if let url = URL(string: ProRobot.HELP_URL_SKATECONNECT) {
                            openURL(url)
                        }
                    }
                }
                
                if debugManager.hasEnabledDebug {
                    Button("💾 Backup Data") {
                        Task {
                            if let backupJSON = dataManager.backupData() {
                                UIPasteboard.general.string = backupJSON
                                showCopyNotification = true
                            }
                        }
                    }
                    Button("♻️ Restore Data") {
                        navigation.path.append(NavigationPathType.restoreData)
                    }
                }
                
                Button("Reset App") {
                    showingConfirmation = true
                }
            }
        }
        .sheet(isPresented: $showingQRCodeView) {
            if let npub = npub {
                QRCodeView(npub: npub)
            }
        }
        .confirmationDialog("Are you sure?", isPresented: $showingConfirmation) {
            Button("Reset", role: .destructive) {
                Task {
                    dataManager.resetData()
                    
                    clearAllUserDefaults()
                    
                    eulaManager.resetEULA()
                    debugManager.resetDebug()
                    
                    navigation.tab = .map
                    navigation.activeView = .other
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all app data. Are you sure you want to proceed?")
        }
        .overlay(
            Group {
                if showCopyNotification {
                    Text("Copied to clipboard!")
                        .padding()
                        .background(Color.orange.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopyNotification = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: showCopyNotification),
            alignment: .center
        )
    }
}

func clearAllUserDefaults() {
    if let appDomain = Bundle.main.bundleIdentifier {
        UserDefaults.standard.removePersistentDomain(forName: appDomain)
    }
}

#Preview {
    SettingsView(host: .constant(Host()))
}
