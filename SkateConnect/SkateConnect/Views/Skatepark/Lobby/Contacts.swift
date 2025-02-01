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

    @EnvironmentObject private var debugManager: DebugManager
    @EnvironmentObject private var navigation: Navigation

    @State private var newName = ""
    @State private var newDate = Date.now
    @State private var newNPub = ""

    @State private var showingAlert = false
    @State private var selectedFriend: Friend?

    var body: some View {
        List {
            ForEach(friends) { friend in
                friendRow(for: friend)
            }
            .onDelete(perform: deleteFriend)
        }
        .safeAreaInset(edge: .bottom) {
            newFriendForm
        }
        .alert("Contact added.", isPresented: $showingAlert) {
            Button("Ok", role: .cancel) {
                showingAlert = false
            }
        }
        .sheet(item: $selectedFriend) { friend in
                EditCryptoAddressesView(friend: friend)
        }
        .onReceive(NotificationCenter.default.publisher(for: .barcodeScanned)) { notification in
            if let scannedText = notification.userInfo?["scannedText"] as? String {
                self.newNPub = scannedText.replacingOccurrences(of: "nostr:", with: "")
            }
        }
    }
}

// MARK: - UI Components
private extension Contacts {
    /// Renders a row for each friend in the list
    func friendRow(for friend: Friend) -> some View {
        HStack {
            if friend.isBirthdayToday {
                Image(systemName: "birthday.cake")
            }
            
            Text(friend.name)
                .bold(friend.isBirthdayToday)
                .contextMenu { contextMenu(for: friend) }
            
            Spacer()
            Text(friend.birthday, format: .dateTime.month(.wide).day().year())
            
            if hasWallet() || debugManager.hasEnabledDebug {
                Button(action: {
                    selectedFriend = friend
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
    }

    /// Context menu for each friend
    func contextMenu(for friend: Friend) -> some View {
        Group {
            Button("Open") {
                Task {
                    navigation.path.append(NavigationPathType.userDetail(npub: friend.npub))
                }
            }
            
            Button("Copy npub") {
                UIPasteboard.general.string = friend.npub
            }
            
            Button("Add Note") {
                // Implement note-adding functionality here
            }
        }
    }
    
    /// Form to add a new friend
    var newFriendForm: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("New Friend")
                .font(.headline)
            
            DatePicker(selection: $newDate, in: Date.distantPast...Date.now, displayedComponents: .date) {
                TextField("Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }
            
            TextField("npub", text: $newNPub)
                .textFieldStyle(.roundedBorder)
            
            Button("Scan Barcode") {
                navigation.path.append(NavigationPathType.barcodeScanner)
            }
            
            Button("Save") {
                saveNewFriend()
            }
            .bold()
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - Helper Methods
private extension Contacts {
    /// Deletes a friend
    func deleteFriend(_ friend: Friend) {
        context.delete(friend)
    }
    
    /// Deletes multiple friends via swipe-to-delete
    func deleteFriend(at offsets: IndexSet) {
        for index in offsets {
            context.delete(friends[index])
        }
    }

    /// Saves a new friend to the database
    func saveNewFriend() {
        let newFriend = Friend(name: newName, birthday: newDate, npub: newNPub, note: "")
        context.insert(newFriend)
        showingAlert = true
    }
}
