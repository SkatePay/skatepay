//
//  UserRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserRow: View {
    @ObservedObject var navigation = Navigation.shared

    @State private var isShowingFilters = false
    @State private var selectedUser: User? = nil

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
                            selectedUser = user
                        }) {
                            UserItem(user: user)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .fullScreenCover(item: $selectedUser) { user in
            NavigationView {
                UserDetail(user: user)
                    .navigationBarItems(leading:
                                            Button(action: {
                        selectedUser = nil
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Lobby")
                            Spacer()
                        }
                    })
            }
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
