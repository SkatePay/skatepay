//
//  LobbyHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import NostrSDK
import SwiftUI

struct LobbyHome: View {
    @Environment(ModelData.self) var modelData
    
    @EnvironmentObject var hostStore: HostStore
    @EnvironmentObject var room: Room
    
    @State private var showingProfile = false
    
    var body: some View {
        NavigationSplitView {
            List {
                UserRow(users: modelData.users)
                
                NavigationLink {
                    DirectMessage(senderPrivateKey: hostStore.host.nsec).environment(modelData)
                } label: {
                    Text("💌 Direct Message")
                }
                
                NavigationLink {
                    AddressBook()
                } label: {
                    Text("📕 Address Book")
                }
                
                ForEach(Array(room.guests.keys), id: \.self) { key in
                    Text("😎 \(key)")
                        .font(.caption)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = key
                            }) {
                                Text("Copy")
                            }
                        }
                }
                
                Spacer()
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
        } detail: {
            Text("Select a Landmark")
        }
        
    }
}

#Preview {
    LobbyHome().environment(ModelData())
}
