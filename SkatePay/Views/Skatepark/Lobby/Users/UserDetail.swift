//
//  UserDetail.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK


struct UserDetail: View {
    @Environment(SkatePayData.self) var modelData
        
    @EnvironmentObject var viewModel: ContentViewModel
        
    @State var showingConnector = false
    
    var user: User
    
    var userIndex: Int {
        modelData.users.firstIndex(where: { $0.id == user.id })!
    }
    
    var connected: Bool { viewModel.relayPool.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) }
    
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
                     FavoriteButton(isSet: $modelData.users[userIndex].isFavorite)
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
                
                Text("Relay")
                    .font(.title2)
                Text("\(user.relayUrl) \(connected ? "🟢" : "🔴")" )
                
                Divider()
                
                
                HStack {
                    Spacer()
                    
                    NavigationLink {
                        DirectChat(user: user)
                    } label: {
                        Label("Chat", systemImage: "folder")
                    }
                }
                .padding(15)
                
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let modelData = SkatePayData()
    return UserDetail(user: modelData.users[0])
        .environment(modelData).environmentObject(HostStore())
}
