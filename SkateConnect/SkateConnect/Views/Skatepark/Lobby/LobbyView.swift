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
    
    var body: some View {
        VStack {
            List {
                let bots = loadBotsFromUserDefaults()
                let botUsers = bots.map { bot in
                    SkateConnect.getUser(npub: bot.npub)
                }
                
                let users = [SkateConnect.getUser(npub: modelData.users[0].npub)] + botUsers
                
                UserRow(users: users)
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
            let defaults = UserDefaults.standard
            
            if !defaults.bool(forKey: UserDefaults.Keys.hasRunOnboarding) {
                isShowingAlert = true
            }
        }
        .alert("🧑‍🏫 Instructions", isPresented: $isShowingAlert) {
            Button("Got it!", role: .cancel) {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: UserDefaults.Keys.hasRunOnboarding)
            }
        } message: {
            Text("Tap and hold message, contact or other to see the options menu.")
        }
    }
}

private extension LobbyView {
    func formatTimeAgo(_ timestamp: Int64) -> String {
        let now = Int64(Date().timeIntervalSince1970)
        let secondsAgo = now - timestamp
        
        if secondsAgo < 60 {
            return "\(secondsAgo) sec. ago"
        } else if secondsAgo < 3600 {
            let minutes = secondsAgo / 60
            return "\(minutes) min. ago"
        } else if secondsAgo < 86400 {
            let hours = secondsAgo / 3600
            return "\(hours) hr. ago"
        } else if secondsAgo < 172800 {
            return "yesterday"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            return dateFormatter.string(from: date)
        }
    }
    
    func formatActivity(npub: String, text: String?) -> String {
        var alias = friendlyKey(npub: npub)

        guard let text = text else {
            if let friend = self.dataManager.findFriend(npub) {
                if (friend.note.isEmpty) {
                    alias = friend.name
                } else {
                    alias = friend.note
                }
            }
            return "Incoming message from \(alias)"
        }
        
        if let friend = self.dataManager.findFriend(npub) {
            if (friend.note.isEmpty) {
                alias = friend.name
            } else {
                alias = friend.note
            }
        }
        return "\(alias): \(text)"
    }
    
    private func contextMenu(for npub: String) -> some View {
        Group {
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
    
    var activity: some View {
        Section("Events") {
            let groupedEvents = lobby.groupedEvents() // Compute once

            if groupedEvents.isEmpty {
                Text("No incoming messages found.")
                    .font(.caption)
            } else {
                let sortedGroups = groupedEvents.keys.sorted { npub1, npub2 in
                    guard let events1 = groupedEvents[npub1], let events2 = groupedEvents[npub2] else { return false }
                    return events1.first!.createdAt > events2.first!.createdAt
                }

                ForEach(sortedGroups, id: \.self) { npub in
                    if let events = groupedEvents[npub], let lastEvent = events.first {
                        let isRead = lobby.isMessageRead(npub: npub, timestamp: lastEvent.createdAt)

                        VStack(alignment: .leading) {
                            HStack {
                                Button(action: {
                                    if !isRead {
                                        lobby.markMessageAsRead(npub: npub, timestamp: lastEvent.createdAt)
                                    }
                                }) {
                                    Image(systemName: isRead ? "envelope.open" : "envelope")
                                        .foregroundColor(isRead ? .gray : .blue)
                                        .animation(.easeInOut, value: isRead)
                                }

                                Text(formatActivity(npub: npub, text: lastEvent.text))
                                    .font(.caption)
                                Spacer()
                                Text(formatTimeAgo(lastEvent.createdAt))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .contextMenu { contextMenu(for: npub) }
                        }
                    }
                }
            }
        }
    }

    func loadBotsFromUserDefaults() -> [CodableBot] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "importedBots") else { return [] }
        do {
            return try JSONDecoder().decode([CodableBot].self, from: data)
        } catch {
            print("Failed to load bots from UserDefaults: \(error)")
            return []
        }
    }
}

#Preview {
    LobbyView().environment(AppData())
}
