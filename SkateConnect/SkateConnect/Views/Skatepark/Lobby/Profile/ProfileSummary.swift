//
//  ProfileSummary.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI


struct ProfileSummary: View {
    var profile: Profile


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(profile.username)
                    .bold()
                    .font(.title)


                Text("Notifications: \(profile.prefersNotifications ? "On": "Off" )")
                Text("Moods: \(profile.seasonalPhoto.rawValue)")
                Text("Birthday: ") + Text(profile.birthday, style: .date)
            }
        }
    }
}


#Preview {
    ProfileSummary(profile: Profile.default)
}
