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
    
    @State private var solanaAddress = ""
    
    @State private var selectedPublicKey: String = ""
    
    @State var showingAlert = false

    func findFriendByPublicKey(_ npub: String) -> Friend? {
        return friends.first { $0.npub == npub }
    }
    
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
                                Task {
                                    navigation.selectedUserNpub = friend.npub
                                    navigation.isShowingUserDetail = true
                                }
                            }) {
                                Text("Open")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = friend.npub
                            }) {
                                Text("Copy npub")
                            }
                            
                            if (hasWallet() || debugManager.hasEnabledDebug) {
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
                    
                    Button("Scan Barcode") {
                        navigation.activeSheet = .barcodeScanner
                    }
                    
                    if (hasWallet() || debugManager.hasEnabledDebug) {
                        TextField("solana account", text: $solanaAddress)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Save") {
                        let newFriend = Friend(name: newName, birthday: newDate, npub: newNPub, solanaAddress: solanaAddress, note: "")
                        context.insert(newFriend)
                        
                        showingAlert = true
                    }
                    .bold()
                }
                .padding()
                .background(.bar)
            }
        }
        .alert("Contact added.", isPresented: $showingAlert) {
            Button("Ok", role: .cancel) {
                showingAlert = false
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { navigation.activeSheet == .barcodeScanner },
            set: { if !$0 { navigation.activeSheet = .none } }
        )) {
            NavigationView {
                BarcodeScanner()
                    .environmentObject(navigation)
            }
        }
        .animation(.easeInOut, value: navigation.isShowingUserDetail)
        .onReceive(NotificationCenter.default.publisher(for: .barcodeScanned)) { notification in
            
            func cleanNostrPrefix(_ input: String) -> String {
                return input.replacingOccurrences(of: "nostr:", with: "")
            }
            
            if let scannedText = notification.userInfo?["scannedText"] as? String {
                self.newNPub = cleanNostrPrefix(scannedText)
            }
        }
    }
}

func getUser(npub: String) -> User {
    var user = User(
        id: 1,
        name: friendlyKey(npub: npub),
        npub: npub,
        solanaAddress: "SolanaAddress1...",
        relayUrl: Constants.RELAY_URL_SKATEPARK,
        isFavorite: false,
        note: "Not provided.",
        imageName: "user-skatepay"
    )
    
    if (npub == AppData().getSupport().npub) {
        user = AppData().users[0]
    }
    
    return user
}


#Preview {
    Contacts().modelContainer(for: Friend.self, inMemory: true)
}
