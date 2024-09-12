//
//  MockUser.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Foundation
import ExyteChat

struct MockUser: Equatable {
    let uid: String
    let name: String
    let avatar: URL?

    init(uid: String, name: String, avatar: URL? = nil) {
        self.uid = uid
        self.name = name
        self.avatar = avatar
    }
}

extension MockUser {
    var isCurrentUser: Bool {
        uid == "1"
    }
}

extension MockUser {
    func toChatUser() -> ExyteChat.User {
        ExyteChat.User(id: uid, name: name, avatarURL: avatar, isCurrentUser: isCurrentUser)
    }
}
