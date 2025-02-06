//
//  UserRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserRow: View {
    @EnvironmentObject private var navigation: Navigation
        
    var users: [User]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Favorites")
                    .font(.headline)
                    .padding(.leading, 15)
                    .padding(.top, 5)
                Spacer()
                Button(action: {
                    navigation.path.append(NavigationPathType.filters)
                }) {
                    Text("Ignore")
                        .foregroundColor(.blue)
                        .font(.headline)
                        .padding(.leading, 15)
                        .padding(.top, 5)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(users) { user in
                        Button(action: {
                            navigation.path.append(NavigationPathType.userDetail(npub: user.npub))
                        }) {
                            UserItem(user: user)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }
}

#Preview {
    let users = AppData().users
    return UserRow(
        users: Array(users.prefix(6))
    )
}
