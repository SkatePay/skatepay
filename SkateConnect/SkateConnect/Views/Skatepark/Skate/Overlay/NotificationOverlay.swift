//
//  NotificationOverlay.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI

struct NotificationOverlay: View {
    @Binding var isInviteCopied: Bool
    @Binding var isLinkCopied: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if isInviteCopied {
                Text("Invite copied! Paste in DM or a channel.")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .zIndex(1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isInviteCopied = false
                            }
                        }
                    }
            }
            
            if isLinkCopied {
                Text("Link copied. Share it with friends!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .zIndex(1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isLinkCopied = false
                            }
                        }
                    }
            }
        }
    }
}
