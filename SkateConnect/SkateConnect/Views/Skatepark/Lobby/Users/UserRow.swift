//
//  UserRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserRow: View {
    @Environment(\.modelContext) private var context

    @State private var isShowingFilters = false

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
                    isShowingFilters = true
                }) {
                    Text("Ignore")
                        .font(.headline)
                        .padding(.leading, 15)
                        .padding(.top, 5)
                }
            }

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
        .fullScreenCover(isPresented: $isShowingFilters) {
            NavigationView {
                Filters()
                    .navigationBarTitle("Filters")
                    .navigationBarItems(leading:
                                            Button(action: {
                        isShowingFilters = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("⛺️ Lobby")
                            Spacer()
                        }
                    })
            }
        }
    }
}

#Preview {
    let users = AppData().users
    return UserRow(
        users: Array(users.prefix(6))
    )
}
