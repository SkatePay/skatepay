//
//  ProfileEditor.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct ProfileEditor: View {
    @Binding var profile: Profile
    
    var dateRange: ClosedRange<Date> {
        let min = Calendar.current.date(byAdding: .year, value: -1, to: profile.birthday)!
        let max = Calendar.current.date(byAdding: .year, value: 1, to: profile.birthday)!
        return min...max
    }
    
    var body: some View {
        List {
            HStack {
                Text("Username")
                Spacer()
                TextField("Username", text: $profile.username)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            Toggle(isOn: $profile.prefersNotifications) {
                Text("Enable Notifications")
            }
            
            Picker("Style", selection: $profile.style) {
                 ForEach(Profile.Style.allCases) { style in
                     Text(style.rawValue).tag(style)
                 }
            }
            
            DatePicker(selection: $profile.birthday, in: dateRange, displayedComponents: .date) {
                  Text("Birthday")
            }
        }
    }
}


#Preview {
    ProfileEditor(profile: .constant(.default))
}
