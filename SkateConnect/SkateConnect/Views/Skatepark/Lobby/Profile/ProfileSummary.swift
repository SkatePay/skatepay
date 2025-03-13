//
//  ProfileSummary.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI


struct ProfileSummary: View {
    let keychainForNostr = NostrKeychainStorage()

    var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let npub = keychainForNostr.account?.publicKey.npub {
                    Text(MainHelper.friendlyKey(npub: npub))
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = MainHelper.friendlyKey(npub: npub)
                            }) {
                                Text("Copy")
                            }
                        }
                        .bold()
                        .font(.title)
                }

                Text("Notifications: \(profile.prefersNotifications ? "On": "Off" )")
                Text("Style: \(profile.style.rawValue)")
                Text("Birthday: ") + Text(profile.birthday, style: .date)
            }
        }
    }
}


#Preview {
    ProfileSummary(profile: Profile.default)
}
