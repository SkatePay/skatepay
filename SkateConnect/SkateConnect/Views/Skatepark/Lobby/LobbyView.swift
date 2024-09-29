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

struct LobbyView: View {
    @Environment(AppData.self) var modelData
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var hostStore: HostStore
    
    @ObservedObject var navigation = Navigation.shared
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var lobby = Lobby.shared

    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isShowingProfile = false
    @State private var isShowingChatView = false
    
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
                            isShowingChatView = true
                        }) {
                            Label("Open", systemImage: "message")
                        }
                        
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
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    UserRow(users: [modelData.users[0]])
                    
                    Button(action: {
                        navigation.isShowingAddressBook.toggle()
                    }) {
                        Text("📘 Address Book")
                    }
                    .fullScreenCover(isPresented: $navigation.isShowingAddressBook) {
                        NavigationView {
                            AddressBook()
                                .navigationBarTitle("Address Book")
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
                        Text("🖋️ Message")
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
            .navigationTitle("⛺️ Lobby")
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
        .fullScreenCover(isPresented: $isShowingChatView) {
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
            
            let user = try? JSONDecoder().decode(User.self, from: jsonData)
            
            NavigationView {
                DirectMessage(user: user!)
            }
        }
        .onAppear() {
            lobby.events = []
        }
    }
}

#Preview {
    LobbyView().environment(AppData())
}
