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

class UserSelectionManager: ObservableObject {
    @Published var npub: String = ""
}

struct Contacts: View {
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Environment(\.modelContext) private var context
    
    @ObservedObject var navigation = Navigation.shared

    @State private var newName = ""
    @State private var newDate = Date.now
    @State private var newNPub = ""
    
    @State private var solanaAddress = ""
    
    @State private var isShowingUserDetail = false

    @State private var selectedPublicKey: String = ""
    
    @StateObject private var userSelection = UserSelectionManager()

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
                                    userSelection.npub = friend.npub
                                    isShowingUserDetail = true
                                }
                            }) {
                                Text("Open")
                            }
                            
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
                        navigation.isShowingBarcodeScanner = true
                    }
                    
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
                context.insert(Friend(name: AppData().users[0].name, birthday: Date.now, npub: AppData().users[0].npub, solanaAddress: AppData().users[0].solanaAddress,  note: "🐝💤💤💤"))
            }
        }
        .fullScreenCover(isPresented: $isShowingUserDetail) {
            if let friend = findFriendByPublicKey(userSelection.npub) {
                let user = User(
                    id: 1,
                    name: friend.name,
                    npub: friend.npub,
                    solanaAddress: "SolanaAddress1...",
                    relayUrl: Constants.RELAY_URL_PRIMAL,
                    isFavorite: false,
                    note: "Not provided.",
                    imageName: "user-skatepay"
                )
                
                NavigationView {
                    UserDetail(user: user)
                        .navigationBarItems(leading:
                                                Button(action: {
                            isShowingUserDetail = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Direct Chat")
                                Spacer()
                            }
                        })
                }
            }
        }
        .fullScreenCover(isPresented: $navigation.isShowingBarcodeScanner) {
            NavigationView {
                BarcodeScanner()
            }
        }
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


#Preview {
    Contacts().modelContainer(for: Friend.self, inMemory: true)
}
