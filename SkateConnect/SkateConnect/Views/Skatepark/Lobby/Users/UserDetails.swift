//
//  UserDetails.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import os
import NostrSDK
import SwiftData
import SwiftUI

struct UserDetails: View {
    let log = OSLog(subsystem: "SkateConnect", category: "UserDetails")

    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var debugManager: DebugManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
        
    @Query(sort: \Friend.npub) private var friends: [Friend]
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isDebugging = false
    @State private var showingConnector = false
    @State private var isFavorite: Bool = false
    @State private var selectedSectionTag: Int = 1 // Default to Info (tag 1)
    
    @StateObject private var eventPublisher = NotesPublisher()
    @StateObject private var eventListener = NotesListener()
    
    var user: User
    
    let keychainForNostr = NostrKeychainStorage()
    
    var connected: Bool {
        network.relayPool?.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) ?? false
    }
        
    private func isFriend() -> Bool {
        friends.contains(where: { $0.npub == user.npub })
    }
    
    var contact: Friend? {
        friends.first(where: { $0.npub == user.npub })
    }
        
    private func isFoe() -> Bool {
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
            VStack(spacing: 20) {
                
                CircleImage(image: user.image)
                    .padding(.top)

                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        Text(user.name + " \(getMonkey())")
                            .font(.title)
                            .fontWeight(.medium)
                        
                        FavoriteButton(isSet: $isFavorite)
                              .onAppear { isFavorite = isFriend() }
                        
                        Spacer()
                    }

                    Text(user.npub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 40)
                        .contextMenu {
                            Button("Copy npub") {
                                UIPasteboard.general.string = user.npub
                            }
                        }
                }

                Divider()

                HStack(spacing: 15) {
                     NavigationLink(value: NavigationPathType.directMessage(user: user)) {
                         Label("Chat", systemImage: "message.fill")
                             .frame(maxWidth: .infinity)
                     }
                     .buttonStyle(.borderedProminent)
                     .tint(.green)

                     if !isSupport() {
                         BlockUnblockButton(user: user)
                             .environmentObject(dataManager)
                             .frame(maxWidth: .infinity)
                     }
                }
                .padding(.horizontal)

                TabView(selection: $selectedSectionTag) {
                    deckSectionView
                        .tag(0)

                    infoSectionView
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 300)

                if isDebugging {
                    VStack(alignment: .leading, spacing: 4) {
                         Divider()
                         Text("Debug Info")
                             .font(.title3)
                             .fontWeight(.semibold)
                        Text("Relay: \(user.relayUrl) \(connected ? "🟢" : "🔴")")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
            }
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSupport() {
                    Button {
                        let destination = NavigationPathType.reportUser(
                            user: AppData().getSupport(),
                            message: user.npub
                        )
                        navigation.path.append(destination)
                    } label: {
                        Image(systemName: "exclamationmark.bubble.fill")
                    }
                    .tint(.red)
                }
            }
        }
        .onAppear() {
            guard let publicKey = PublicKey(npub: user.npub) else {
                os_log("🔥 can't get user account", log: log, type: .error)
                return
            }
            
            guard let account = keychainForNostr.account else {
                os_log("🔥 can't get account", log: log, type: .error)
                return
            }

            self.eventListener.setPublicKey(publicKey)
            self.eventListener.setDependencies(dataManager: dataManager, debugManager: debugManager, account: account)
            self.eventPublisher.subscribeToNotesWithPublicKey(publicKey)
            
            isFavorite = isFriend()
        }
        .onChange(of: eventListener.receivedEOSE) { _, eoseReceived in
            var showDeckPage = false
            if eoseReceived {
                if let firstNote = self.eventListener.notesFromDeckTracker.first, case .deck(_) = firstNote {
                     showDeckPage = true
                }
            }
            self.selectedSectionTag = showDeckPage ? 0 : 1
        }
        .onChange(of: isFavorite) { _, newValue in
            if (isSupport()) {
                return
            }
            persistFavoriteChange(isNowFavorite: newValue)
        }
    }
    
    private func persistFavoriteChange(isNowFavorite: Bool) {
         if isNowFavorite {
             if dataManager.findFriend(user.npub) == nil {
                 let newFriend = Friend(name: user.name, birthday: Date.now, npub: user.npub, note: "")
                 context.insert(newFriend)
                 os_log("✅ Friend added: %{public}@", log: log, user.npub)
             }
         } else {
             if let friend = dataManager.findFriend(user.npub) {
                 context.delete(friend)
                 os_log("❌ Friend removed: %{public}@", log: log, user.npub)
             }
         }
    }
    
    private var infoSectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
           Divider()
           Text("Info")
             .font(.title3)
             .fontWeight(.semibold)
             .gesture(LongPressGesture(minimumDuration: 1.0).onEnded { _ in self.isDebugging = true })

           Group {
               if let contact = contact, !contact.note.isEmpty {
                   Text(contact.note)
               } else {
                   Text(user.note.isEmpty ? "Not provided." : user.note)
               }
           }
           .font(.body)
           .foregroundStyle(.primary)
           .frame(maxWidth: .infinity, alignment: .leading)
           .contextMenu {
               Button("Copy note") {
                   UIPasteboard.general.string = contact?.note ?? user.note
               }
           }
           Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var deckSectionView: some View {
         VStack(alignment: .leading, spacing: 8) {
             Divider()
             Text("Tracked Deck")
                 .font(.title3)
                 .fontWeight(.semibold)
             DeckView(notes: self.eventListener.notesFromDeckTracker)
             Spacer()
         }
         .padding(.horizontal)
         .padding(.top)
    }
}

struct BlockUnblockButton: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dataManager: DataManager

    var user: User

    var body: some View {
        Group {
            if let foe = dataManager.findFoes(user.npub) {
                Button("Unmute", role: .destructive) {
                    context.delete(foe)
                }
            } else {
                Button("Mute") {
                    let newFoe = Foe(npub: user.npub, birthday: Date.now, note: "")
                    context.insert(newFoe)
                    NotificationCenter.default.post(name: .muteUser, object: nil, userInfo: ["npub": user.npub])
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
}


struct DeckView: View {
    var notes: [NoteType] = []

    var body: some View {
        if let firstNote = notes.first {
            switch firstNote {
            case .deck(let deck):
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if let url = deck.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        ProgressView()
                                    }
                                case .success(let loadedImage):
                                    loadedImage
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        Image(systemName: "photo.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                             ZStack {
                                Color(.secondarySystemBackground)
                                Image(uiImage: deck.image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                             }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 4)


                    Text(deck.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Text(deck.brand.isEmpty ? "Unknown Brand" : deck.brand)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(deck.width, specifier: "%.3f")\" Wide")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        if !deck.notes.isEmpty {
                            Text("Notes:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(deck.notes)
                                .font(.body)
                            Divider().padding(.vertical, 2)
                        }

                        HStack {
//                            Text("Purchased:")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                            Text(deck.purchaseDate, style: .date)
//                                .font(.caption)

                            Spacer()

                             Text("Added:")
                                 .font(.caption)
                                 .foregroundStyle(.secondary)
                            Text(deck.createdAt, style: .date)
                               .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)


            case .unknown:
                Text("No deck information found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } else {
             Text("No decks available.")
                 .foregroundStyle(.secondary)
                 .frame(maxWidth: .infinity, alignment: .center)
                 .padding()
        }
    }
}
