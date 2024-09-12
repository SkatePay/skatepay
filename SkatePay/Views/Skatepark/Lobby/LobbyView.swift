//
//  LobbyView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftData
import SwiftUI

class FriendsViewModel: ObservableObject {
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    func findFriendBySolanaAddress(_ address: String) -> Friend? {
        print(address)
        return friends.first { $0.solanaAddress == address }
    }
}

struct LobbyView: View {
    @Environment(AppData.self) var modelData
    @StateObject private var viewModel = FriendsViewModel()
    
    @EnvironmentObject var hostStore: HostStore
    @EnvironmentObject var room: Lobby
    
    @State private var showingProfile = false
    @State private var showChatView = false
    @State private var npub = ""
    
    var activity: some View {
        Section("Activity") {
            ForEach(room.nostrEvents,  id: \.id) { event in
                Text("✉️ Incoming message from \(event.npub.prefix(4))...\(event.npub.suffix(4))")
                    .font(.caption)
                    .contextMenu {
                        Button(action: {
                            showChatView = true
                            DispatchQueue.main.async {
                                npub = event.npub
                            }
                        }) {
                            Text("Open")
                        }
                        
                        Button(action: {
                            UIPasteboard.general.string = event.npub
                        }) {
                            Text("Copy")
                        }
                    }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                UserRow(users: modelData.users)
                
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
                    CreateMessage().environment(modelData)
                } label: {
                    Text("🖋️ Message")
                }
                
                activity
            }
            .navigationTitle("🏛️ Lobby")
            .toolbar {
                Button {
                    showingProfile.toggle()
                } label: {
                    Label("User Profile", systemImage: "person.crop.circle")
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileHost()
                    .environment(modelData)
            }
        }
        .fullScreenCover(isPresented: $showChatView) {
            let jsonData = """
            {
                "id": 1,
                "name": "ghost",
                "npub": "\(npub)",
                "solanaAddress": "",
                "relayUrl": "\(AppConstants.RELAY_URL_PRIMAL)",
                "isFavorite": false,
                "imageName": "user-ghost"
            }
            """.data(using: .utf8)!

            let user = try? JSONDecoder().decode(User.self, from: jsonData)
        
            NavigationView {
                DirectChat(user: user!)
            }
        }
    }
}

#Preview {
    LobbyView().environment(AppData())
}
