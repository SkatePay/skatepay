//
//  LobbyView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftUI

struct LobbyView: View {
    @Environment(ModelData.self) var modelData
    
    @EnvironmentObject var hostStore: HostStore
    @EnvironmentObject var room: Lobby
    
    @State private var showingProfile = false
    
    var body: some View {
        NavigationStack {
            List {
                UserRow(users: modelData.users)
                
                NavigationLink {
                    AddressBook()
                } label: {
                    Text("📕 Address Book")
                }
                
                NavigationLink {
                    Contacts()
                } label: {
                    Text("☎️ Connections")
                }
                
                NavigationLink {
                    DirectMessage(senderPrivateKey: hostStore.host.nsec).environment(modelData)
                } label: {
                    Text("💌 Messages")
                }
                
                Section("Activity") {
                    ForEach(Array(room.guests.keys), id: \.self) { key in
                        Text("📦 \(key)")
                            .font(.caption)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = key
                                }) {
                                    Text("Copy")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Virtual Skatepark")
            .toolbar {
                Button {
                    showingProfile.toggle()
                } label: {
                    Label("User Profile", systemImage: "person.crop.circle")
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileHost()
                    .environment(modelData)
            }
        }
    }
}

#Preview {
    LobbyView().environment(ModelData())
}
