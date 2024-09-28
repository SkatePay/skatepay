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
    
    @ObservedObject var lobby = Lobby.shared
    @ObservedObject var navigation = Navigation.shared

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

        // TODO: Needs rework bad filtering
        let npubs = lobby.events
            .filter ({ !self.isFoe($0.npub) })
            .filter({ $0.npub != npub })
            .map { $0.npub }
                
        let uniqueNpubs = Set(npubs)
        
        return Array(uniqueNpubs)
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
                        Text("Incoming message from \(friendlyKey(npub: npub))")
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
        NavigationStack(path: $navigation.path)  {
            List {
                UserRow(users: [modelData.users[0]])
                
                NavigationLink {
                    AddressBook()
                } label: {
                    Text("📘 Address Book")
                }
                
                NavigationLink {
                    Contacts()
                } label: {
                    Text("🤝 Friends")
                }
                
                NavigationLink {
                    CreateMessage()
                } label: {
                    Text("🖋️ Message")
                }
                
                activity
            }
            .navigationTitle("⛺️ Lobby")
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
            }
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
