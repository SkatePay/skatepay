//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import SwiftUI

struct ToolBoxView: View {
    @State private var isInviteCopied = false
    
    @ObservedObject var navigation = Navigation.shared
    
    var body: some View {
        VStack {
            Text("Toolbox")
                .font(.headline)
                .padding(.top)

            Divider()

                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: 20) {
                         Button(action: {
                             UIPasteboard.general.string = "channel_invite:\(navigation.channelId)"
                             isInviteCopied = true
                             
                             DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                 isInviteCopied = false
                             }
                         }) {
                             VStack {
                                 Image(systemName: "link")
                                     .resizable()
                                     .frame(width: 40, height: 40)
                                     .foregroundColor(.blue)
                                 Text("Copy Invite")
                                     .font(.caption)
                             }
                         }
                     }
                     .padding(.horizontal)
                 }
             
            Spacer()
            
            if isInviteCopied {
                Text("Invite copied!")
                    .foregroundColor(.green)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .animation(.easeInOut, value: isInviteCopied)
    }
}

#Preview {
    ToolBoxView()
}
