//
//  UserItem.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct UserItem: View {
    var user: User

    var body: some View {
        VStack(alignment: .center) {
            user.image
                .renderingMode(.original)
                .resizable()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .shadow(radius: 1)
                .cornerRadius(1)
            Text(user.name)
                .foregroundStyle(.primary)
                .font(.caption)
        }
        .padding(.leading, 15)
    }
}


#Preview {
    UserItem(user: AppData().users[0])
}
