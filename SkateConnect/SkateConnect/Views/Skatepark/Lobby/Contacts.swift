//
//  Contacts.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI
import SwiftData

struct Contacts: View {
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Environment(\.modelContext) private var context
    
    @State private var newName = ""
    @State private var newDate = Date.now
    @State private var newNPub = ""
    
    @State private var solanaAddress = ""
    
    var body: some View {
        NavigationStack {
            List(friends) { friend in
                HStack {
                    if friend.isBirthdayToday {
                        Image(systemName: "birthday.cake")
                    }
                    
                    Text(friend.name)
                        .bold(friend.isBirthdayToday)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = friend.npub
                            }) {
                                Text("Copy npub")
                            }
                            
                            if (hasWallet()) {
                                Button(action: {
                                    UIPasteboard.general.string = friend.solanaAddress
                                }) {
                                    Text("Copy solana address")
                                }
                            }

                            Button(action: {
                                UIPasteboard.general.string = friend.npub
                            }) {
                                Text("Add note")
                            }
                            Button(action: {
                                context.delete(friend)
                            }) {
                                Text("Delete")
                            }
                        }
                    
                    Spacer()
                    Text(friend.birthday, format: .dateTime.month(.wide).day().year())
                }
            }
            .navigationTitle("Friends")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 20) {
                    Text("New Friend")
                        .font(.headline)
                    DatePicker(selection: $newDate, in: Date.distantPast...Date.now, displayedComponents: .date) {
                        TextField("name", text: $newName)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("npub", text: $newNPub)
                        .textFieldStyle(.roundedBorder)
                    
                    if (hasWallet()) {
                        TextField("solana account", text: $solanaAddress)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Save") {
                        let newFriend = Friend(name: newName, birthday: newDate, npub: newNPub, solanaAddress: solanaAddress, note: "")
                        context.insert(newFriend)
                    }
                    .bold()
                }
                .padding()
                .background(.bar)
            }
            .task {
                context.insert(Friend(name: AppData().users[0].name, birthday: Date(timeIntervalSince1970: 0), npub: AppData().users[0].npub, solanaAddress: AppData().users[0].solanaAddress,  note: "🐝💤💤💤"))
            }
        }
    }
}


#Preview {
    Contacts().modelContainer(for: Friend.self, inMemory: true)
}
