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
    @EnvironmentObject var room: Lobby
    
    @StateObject private var viewModel = FriendsViewModel()
    
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isShowingProfile = false
    @State private var isShowingChatView = false
    
    @State private var npub = ""
    
    func isFoe(_ npub: String) -> Bool {
        return foes.contains(where: { $0.npub == npub })
    }
    
    func parseActivity() -> [ActivityEvent] {
        let events = room.events.filter ({ !self.isFoe($0.npub) })
        return events
    }
    
    var activity: some View {
        Section("Activity") {
            if parseActivity().isEmpty {
                
                Text("No incoming messages found.")
                    .font(.caption)
            } else {
                ForEach(parseActivity(),  id: \.id) { event in
                    Text("✉️ Incoming message from \(event.npub.prefix(4))...\(event.npub.suffix(4))")
                        .font(.caption)
                        .contextMenu {
                            Button(action: {
                                DispatchQueue.main.async {
                                    self.npub = event.npub
                                }
                                isShowingChatView = true
                            }) {
                                Text("Open")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = event.npub
                            }) {
                                Text("Copy")
                            }
                            
                            Button(action: {
                                let foe = Foe(npub: event.npub, birthday: Date.now, note: "")
                                context.insert(foe)
                            }) {
                                Text("Block")
                            }
                        }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
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
                        .environment(modelData)
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
                "name": "ghost",
                "npub": "\(self.npub)",
                "solanaAddress": "",
                "relayUrl": "\(Constants.RELAY_URL_PRIMAL)",
                "isFavorite": false,
                "imageName": "user-ghost",
                "note": ""
            }
            """.data(using: .utf8)!
            
            let user = try? JSONDecoder().decode(User.self, from: jsonData)
            
            NavigationView {
                DirectChat(user: user!)
            }
        }
        .onAppear() {
            room.events = []
        }
    }
}

#Preview {
    LobbyView().environment(AppData())
}
