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

    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var eulaManager: EULAManager
    @EnvironmentObject var navigation: Navigation
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
                    if let account = keychainForNostr.account {
                        Text("\(account.publicKey.npub)")
                            .contextMenu {
                                Button(action: {
                                    self.npub = account.publicKey.npub
                                    showingQRCodeView.toggle()
                                }) {
                                    Text("Show QR")
                                }
                            
                                Button(action: {
                                    UIPasteboard.general.string = account.publicKey.npub
                                    showCopyNotification = true
                                }) {
                                    Text("Copy Public Key")
                                }
                            
                                Button(action: {
                                    UIPasteboard.general.string = account.privateKey.nsec
                                    showCopyNotification = true
                                }) {
                                    Text("Copy Secret Key")
                                }
                            
                                if debugManager.hasEnabledDebug {
                                    Button(action: {
                                        UIPasteboard.general.string = account.publicKey.hex
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy phex")
                                    }
                                
                                    Button(action: {
                                        UIPasteboard.general.string = account.privateKey.hex
                                        showCopyNotification = true
                                    }) {
                                        Text("Copy shex")
                                    }
                                }
                        }
                    } else {
                        Text("Create new keys")
                    }
                    
                    Button(action: {
                        navigation.path.append(NavigationPathType.importIdentity)
                    }) {
                        Text("🔑 Keys")
                    }
                    
                    Button(action: {
                        navigation.path.append(NavigationPathType.connectRelay)
                    }) {
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
                    Button("💾 Export Data") {
                        Task {
                            if let backupJSON = dataManager.backupData() {
                                UIPasteboard.general.string = prettifyJSON(backupJSON)
                                showCopyNotification = true
                            }
                        }
                    }
                    Button("📲 Import Data") {
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
                    NotificationCenter.default.post(name: .stopNetwork, object: nil)

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
