//
//  UserDetail.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserDetail: View {
    @Environment(ModelData.self) var modelData

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
                
                Text(user.pubKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                Text("Relay")
                    .font(.title2)
                Text(user.relayUrl)
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
        .environment(modelData)
}
