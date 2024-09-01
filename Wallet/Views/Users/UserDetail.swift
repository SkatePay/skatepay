//
//  UserDetail.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserDetail: View {
    @Environment(ModelData.self) var modelData
    @EnvironmentObject var hostStore: HostStore

    @StateObject private var store = HostStore()

    @State var showingEditor = false
    
    var user: User

    var userIndex: Int {
        modelData.users.firstIndex(where: { $0.id == user.id })!
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
                Text(user.relayUrl)
                
                Divider()
                
                HStack {
                    Spacer()
                    
                    Button("Send Message") {
                        showingEditor.toggle()
                    }
                    .sheet(isPresented: $showingEditor) {
                        print("Sheet dismissed!")
                    } content: {
                        DirectMessage(recipientPublicKey: user.npub, senderPrivateKey: hostStore.host.nsec)
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
    let modelData = ModelData()
    return UserDetail(user: modelData.users[0])
        .environment(modelData).environmentObject(HostStore())
}
