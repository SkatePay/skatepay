//
//  UserDetail.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftData
import SwiftUI

struct UserDetail: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
        
    @Query(sort: \Friend.npub) private var friends: [Friend]
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isDebugging = false
    @State private var showingConnector = false
    
    var user: User
    
    var connected: Bool {
        network.relayPool?.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) ?? false
    }
    
    func isFriend() -> Bool {
        friends.contains(where: { $0.npub == user.npub })
    }
    
    func isFoe() -> Bool {
        foes.contains(where: { $0.npub == user.npub })
    }
    
    private func isSupport() -> Bool {
        user.npub == AppData().getSupport().npub
    }
    
    private func getMonkey() -> String {
        isStringOneOfThree(user.name)
    }
    
    var body: some View {
        ScrollView {
            CircleImage(image: user.image)
                .offset(y: 0)
                .padding(.bottom, 0)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(user.name + " \(getMonkey())")
                        .font(.title)
                    FavoriteButton(isSet: .constant(true))
                }
                
                Text(user.npub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contextMenu {
                        Button("Copy") {
                            UIPasteboard.general.string = user.npub
                        }
                    }
                
                Divider()
                
                HStack(spacing: 20) {
                    if (!isSupport()) {
                        FriendFoeButtons(user: user, isFriend: isFriend(), isFoe: isFoe())
                            .environmentObject(dataManager)
                    }
                    NavigationLink(value: NavigationPathType.directMessage(user: user)) {
                        Label("Chat", systemImage: "message")
                            .padding(8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(15)
                
                Divider()
                
                Text("Info")
                    .font(.title2)
                    .gesture(
                        LongPressGesture(minimumDuration: 1.0)
                            .onEnded { _ in self.isDebugging = true }
                    )
                
                Text(user.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .contextMenu {
                        Button("Copy") {
                            UIPasteboard.general.string = user.npub
                        }
                    }
                
                if (isDebugging) {
                    Text("Relay").font(.title2)
                    Text("\(user.relayUrl) \(connected ? "🟢" : "🔴")")
                }
                
                Divider()
                
                if (!isSupport()) {
                    HStack(spacing: 20) {
                        Spacer()
                        NavigationLink(value: NavigationPathType.reportUser(user: AppData().users[0], message: user.npub)) {
                            Label("Report User", systemImage: "exclamationmark.bubble.fill")
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            Spacer()
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FriendFoeButtons: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dataManager: DataManager

    var user: User
    var isFriend: Bool
    var isFoe: Bool
    
    var body: some View {
        HStack {
            if isFriend {
                Button("Remove from Friends") {
                    if let friend = dataManager.findFriend(user.npub) {
                        context.delete(friend)
                    }
                }
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Button("+1 Contacts") {
                    let friend = Friend(name: friendlyKey(npub: user.npub), birthday: Date.now, npub: user.npub, note: "")
                    context.insert(friend)
                }
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if isFoe {
                Button("Unmute 🙊") {
                    if let foe = dataManager.findFoes(user.npub) {
                        context.delete(foe)
                    }
                }
                .padding(8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Button("Ignore 🙈") {
                    let foe = Foe(npub: user.npub, birthday: Date.now, note: "")
                    context.insert(foe)
                    NotificationCenter.default.post(name: .muteUser, object: nil)
                }
                .padding(8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
}

#Preview {
    let modelData = AppData()
    return UserDetail(user: modelData.users[0])
        .environment(modelData).environmentObject(HostStore())
}
