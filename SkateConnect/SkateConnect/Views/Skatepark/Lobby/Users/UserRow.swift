//
//  UserRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserRow: View {
    var users: [User]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Skaters of The Month")
                .font(.headline)
                .padding(.leading, 15)
                .padding(.top, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(users) { user in
                        NavigationLink {
                            UserDetail(user: user)
                        } label: {
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
