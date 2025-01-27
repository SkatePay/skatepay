//
//  UserRow.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserRow: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigation: Navigation
    
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
                            navigation.selectedUserNpub = user.npub
                            navigation.isShowingUserDetail = true
                        }) {
                            UserItem(user: user)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
//        .fullScreenCover(isPresented: $isShowingUserDetail) { 
//            NavigationView {
//                UserDetail(user: getUser(npub: selectedUserManager.npub))
//                    .environmentObject(navigation)
//                    .navigationBarItems(leading:
//                                            Button(action: {
//                        isShowingUserDetail = false
//                    }) {
//                        HStack {
//                            Image(systemName: "arrow.left")
//                            Text("Lobby")
//                            Spacer()
//                        }
//                    })
//            }
//        }
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
                            Text("🏛️ Lobby")
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
