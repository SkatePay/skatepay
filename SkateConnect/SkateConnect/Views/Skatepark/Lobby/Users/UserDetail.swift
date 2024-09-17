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
    @Environment(AppData.self) var modelData
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var viewModel: ContentViewModel
    @ObservedObject var networkConnections = NetworkConnections.shared

    @Query(sort: \Friend.npub) private var friends: [Friend]
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var showReport = false
    @State var showingConnector = false
    
    var user: User
    
    //    var userIndex: Int {
    //        modelData.users.firstIndex(where: { $0.id == user.id })!
    //    }
    
    func isFriend() -> Bool {
        return friends.contains(where: { $0.npub == user.npub })
    }
    
    func isFoe() -> Bool {
        return foes.contains(where: { $0.npub == user.npub })
    }
    
    var connected: Bool { networkConnections.relayPool.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) }
    
    private func isSupport() -> Bool {
        return user.npub == AppData().users[0].npub
    }
    
    var body: some View {
        @Bindable var modelData = modelData
        
        ScrollView {
            CircleImage(image: user.image)
                .offset(y: 0)
                .padding(.bottom, 0)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(user.name)
                        .font(.title)
                    //                     FavoriteButton(isSet: $modelData.users[userIndex].isFavorite)
                }
                
                Text(user.npub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = user.npub
                        }) {
                            Text("Copy")
                        }
                    }
                
                Divider()
                
                HStack(spacing: 20) {
                    // Button to add to contacts
                    
                    if (!isSupport()) {
                        if (isFriend()) {
                            Button(action: {
                                if let friend = friends.first(where: { $0.npub == user.npub }) {
                                    context.delete(friend)
                                }
                            }) {
                                Text("Remove from Friends")
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        } else {
                            Button(action: {
                                let friend = Friend(name: "skater-\(user.npub.suffix(3))", birthday: Date.now, npub: user.npub, note: "")
                                context.insert(friend)
                            }) {
                                Text("+1 Contacts")
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
     
                        if (isFoe()) {
                            // Button to ignore
                            Button(action: {
                                if let foe = foes.first(where: { $0.npub == user.npub }) {
                                    context.delete(foe)
                                }
                            }) {
                                Text("Unmute 🙊")
                                    .padding(8)
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        } else {
                            // Button to ignore
                            Button(action: {
                                let foe = Foe(npub: user.npub, birthday: Date.now, note: "")
                                context.insert(foe)
                            }) {
                                Text("Ignore 🙈")
                                    .padding(8)
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Navigation link for direct chat
                    NavigationLink(destination: DirectMessage(user: user)) {
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
                
                Text(user.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = user.npub
                        }) {
                            Text("Copy")
                        }
                    }
                
                Text("Relay")
                    .font(.title2)
                Text("\(user.relayUrl) \(connected ? "🟢" : "🔴")" )
                
                Divider()
                
                if (!isSupport()) {
                    HStack(spacing: 20) {
                        Spacer()
                        Button(action: {
                            showReport = true
                        }) {
                            Text("Report User 🚩")
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .fullScreenCover(isPresented: $showReport) {
            NavigationView {
                DirectMessage(user: AppData().users[0])
            }
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let modelData = AppData()
    return UserDetail(user: modelData.users[0])
        .environment(modelData).environmentObject(HostStore())
}
