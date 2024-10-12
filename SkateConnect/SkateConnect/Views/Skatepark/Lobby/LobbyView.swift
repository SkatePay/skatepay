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

class FriendsViewModel: ObservableObject {
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    func findFriendBySolanaAddress(_ address: String) -> Friend? {
        return friends.first { $0.solanaAddress == address }
    }
}

func isSupport(npub: String) -> Bool {
    return npub == AppData().getSupport().npub
}

struct LobbyView: View {
    @Environment(AppData.self) var modelData
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var hostStore: HostStore
    
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var lobby = Lobby.shared
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isShowingProfile = false
    @State private var isShowingAlert = false
    
    @StateObject private var userSelection = UserSelectionManager()
    
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
            .filter { $0 != npub}
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
        Section("Activity") {
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
                            userSelection.npub = npub
                            navigation.isShowingChatView.toggle()
                        }) {
                            Label("Open", systemImage: "message")
                        }
                        
                        if (!isSupport(npub: npub)) {
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
        NavigationView {
            VStack {
                List {
                    UserRow(users: [modelData.users[0]])
                    
                    Button(action: {
                        navigation.isShowingAddressBook.toggle()
                    }) {
                        Text("⛺️ Spots")
                    }
                    .fullScreenCover(isPresented: $navigation.isShowingAddressBook) {
                        NavigationView {
                            AddressBook()
                                .navigationBarTitle("Channels")
                                .navigationBarItems(leading:
                                                        Button(action: {
                                    navigation.isShowingAddressBook = false
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Lobby")
                                        Spacer()
                                    }
                                })
                        }
                    }
                    
                    Button(action: {
                        navigation.isShowingContacts.toggle()
                    }) {
                        Text("🤝 Friends")
                    }
                    .fullScreenCover(isPresented: $navigation.isShowingContacts) {
                        NavigationView {
                            Contacts()
                                .navigationBarTitle("Friends")
                                .navigationBarItems(leading:
                                                        Button(action: {
                                    navigation.isShowingContacts = false
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Lobby")
                                        Spacer()
                                    }
                                })
                        }
                    }
                    
                    Button(action: {
                        navigation.isShowingCreateMessage.toggle()
                    }) {
                        Text("✉️ Message")
                    }
                    .fullScreenCover(isPresented: $navigation.isShowingCreateMessage) {
                        NavigationView {
                            CreateMessage()
                                .navigationBarTitle("Direct Message")
                                .navigationBarItems(leading:
                                                        Button(action: {
                                    navigation.isShowingCreateMessage = false
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Lobby")
                                        Spacer()
                                    }
                                })
                        }
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
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileHost()
                .environment(modelData)
        }
        .fullScreenCover(isPresented: $navigation.isShowingChatView) {
            NavigationView {
                DirectMessage(user: getUser())
            }
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
    
    private func getUser() -> User {
        let jsonData = """
        {
            "id": 1,
            "name": "\(friendlyKey(npub: userSelection.npub))",
            "npub": "\(userSelection.npub)",
            "solanaAddress": "",
            "relayUrl": "\(Constants.RELAY_URL_PRIMAL)",
            "isFavorite": false,
            "imageName": "user-ghost",
            "note": ""
        }
        """.data(using: .utf8)!
        
        var user = try! JSONDecoder().decode(User.self, from: jsonData)
        
        if (self.userSelection.npub == AppData().getSupport().npub) {
            user = AppData().users[0]
        }
        
        return user
    }
}

#Preview {
    LobbyView().environment(AppData())
}
