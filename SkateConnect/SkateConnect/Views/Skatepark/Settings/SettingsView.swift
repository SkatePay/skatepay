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

    @EnvironmentObject var eulaManager: EULAManager
    @EnvironmentObject var lobby: Lobby
    @EnvironmentObject var network: Network
    @EnvironmentObject var navigation: Navigation
    
    @Binding var host: Host

    @State private var keypair: Keypair?
    @State private var nsec: String?
    @State private var npub: String?
    
    @State private var showingConfirmation = false
    @State private var showingQRCodeView = false
    
    let keychainForNostr = NostrKeychainStorage()
    
    var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        }
        return "Unknown Version"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Image("user-funkadelic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                
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
                                        }) {
                                            Text("Copy npub")
                                        }
                                    }
                                    
                                    if let nsec = keychainForNostr.account?.privateKey.nsec {
                                        Button(action: {
                                            UIPasteboard.general.string = nsec
                                        }) {
                                            Text("Copy nsec")
                                        }
                                    }
                                    
                                    if let phex = keychainForNostr.account?.publicKey.hex {
                                        Button(action: {
                                            UIPasteboard.general.string = phex
                                        }) {
                                            Text("Copy phex")
                                        }
                                    }
                                    
                                    if let shex = keychainForNostr.account?.privateKey.hex {
                                        Button(action: {
                                            UIPasteboard.general.string = shex
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
                    
                    Button("Reset App") {
                        showingConfirmation = true
                    }
                    .confirmationDialog("Are you sure?", isPresented: $showingConfirmation) {
                        Button("Reset", role: .destructive) {
                            Task {
                                keychainForNostr.clear()
                                
                                do {
                                    try context.delete(model: Spot.self)
                                    try context.delete(model: Friend.self)
                                    try context.delete(model: Foe.self)
                                    
                                } catch {
                                    print("Failed to delete all spots.")
                                }
                                
                                self.lobby.clear()
                                clearAllUserDefaults()
                                
                                eulaManager.resetEULA()
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will reset all app data. Are you sure you want to proceed?")
                    }
                }
                .navigationTitle("🛠️ Settings")
            }
            .sheet(isPresented: $showingQRCodeView) {
                if let npub = npub {
                    QRCodeView(npub: npub)
                }
            }
        }
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
