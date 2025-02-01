//
//  LobbyView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import ConnectFramework
import NostrSDK
import SwiftData
import SwiftUI

struct LobbyView: View {
    @Environment(AppData.self) var modelData
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var hostStore: HostStore
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var lobby: Lobby
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isShowingProfile = false
    @State private var isShowingAlert = false
        
    let keychainForNostr = NostrKeychainStorage()
    
    func isFoe(_ npub: String) -> Bool {
        return foes.contains(where: { $0.npub == npub })
    }
    
    func parseActivity() -> [String] {
        let npub = keychainForNostr.account?.publicKey.npub
        
        let npubs = lobby.incoming()
            .compactMap { hexString in
                if let publicKey = PublicKey(hex: hexString) {
                    return publicKey.npub
                }
                return nil
            }
            .filter {
                !self.isFoe($0)
            }
            .filter { $0 != npub }
        return npubs
    }
    
    func formatActivity(npub: String) -> String {
        if let friend = self.dataManager.findFriend(npub) {
            return "Incoming message from \(friend.name)"
        } else {
            return "Incoming message from \(friendlyKey(npub: npub))"
        }
    }
    
    var activity: some View {
        Section("Events") {
            let npubs = parseActivity()
            
            if npubs.isEmpty {
                Text("No incoming messages found.")
                    .font(.caption)
            } else {
                ForEach(npubs, id: \.self) { npub in
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text(formatActivity(npub: npub))
                            .font(.caption)
                    }
                    .contextMenu {
                        Button(action: {
                            navigation.path.append(NavigationPathType.userDetail(npub: npub))
                        }) {
                            Label("Open", systemImage: "message")
                        }
                        
                        if !isSupport(npub: npub) {
                            Button(action: {
                                UIPasteboard.general.string = npub
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button(role: .destructive, action: {
                                let foe = Foe(npub: npub, birthday: Date.now, note: "")
                                context.insert(foe)
                            }) {
                                Label("Block", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
            }
        }
    }
    
    let hasRunOnboarding = "hasRunOnboarding"

    var body: some View {
        VStack {
            List {
                UserRow(users: [SkateConnect.getUser(npub: modelData.users[0].npub)])
                    .environmentObject(navigation)
                
                Button(action: {
                    navigation.path.append(NavigationPathType.addressBook)
                }) {
                    Text("⛺️ Spots")
                }
                
                Button(action: {
                    navigation.path.append(NavigationPathType.contacts)
                }) {
                    Text("🫂 Friends")
                }
                
                Button(action: {
                    navigation.path.append(NavigationPathType.createMessage)
                }) {
                    Text("✉️ Message")
                }
                
                activity
            }
        }
        .navigationTitle("🏛️ Lobby")
        .toolbar {
            Button {
                isShowingProfile.toggle()
            } label: {
                Label("User Profile", systemImage: "person.crop.circle")
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileHost()
                .environment(modelData)
                .environmentObject(network)
        }
        .onAppear() {
            lobby.events = []
            
            let defaults = UserDefaults.standard
            
            if !defaults.bool(forKey: hasRunOnboarding) {
                isShowingAlert = true
            }
        }
        .alert("🧑‍🏫 Instructions", isPresented: $isShowingAlert) {
            Button("Got it!", role: .cancel) {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: hasRunOnboarding)
            }
        } message: {
            Text("Tap and hold message, contact or other to see the options menu.")
        }
    }
}

#Preview {
    LobbyView().environment(AppData())
}
