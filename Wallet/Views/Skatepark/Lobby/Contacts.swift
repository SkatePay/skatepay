//
//  Contacts.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import SwiftUI
import SwiftData
import NostrSDK

struct Contacts: View {
    @Query(sort: \Friend.birthday) private var friends: [Friend]
    @Environment(\.modelContext) private var context
    
    @State private var newName = ""
    @State private var newDate = Date.now
    @State private var newNPub = ""
    
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
                                Text("Copy")
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
                        TextField("Name", text: $newName)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("npub", text: $newNPub)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Save") {
                        let newFriend = Friend(name: newName, birthday: newDate, npub: newNPub)
                        context.insert(newFriend)
                    }
                    .bold()
                }
                .padding()
                .background(.bar)
            }
            .task {
//                do {
//                    try context.delete(model: Friend.self)
//                } catch {
//                    print("Failed to clear Friend.")
//                }
                context.insert(Friend(name: ModelData().users[0].name, birthday: Date(timeIntervalSince1970: 0), npub: ModelData().users[0].npub))
            }
        }
    }
}


#Preview {
    Contacts().modelContainer(for: Friend.self, inMemory: true)
}
