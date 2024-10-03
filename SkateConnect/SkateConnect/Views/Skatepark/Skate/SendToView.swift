//
//  SendToView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import SwiftUI

struct SendToView: View {
    var body: some View {
        VStack {
            // "Send to" title
            Text("Send to")
                .font(.headline)
                .padding(.top)
            
            Divider()

            // Row for quick send options (like friends or groups)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Example users
                    VStack {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                        Text("User 1")
                            .font(.caption)
                    }

                    VStack {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                        Text("User 2")
                            .font(.caption)
                    }

                    // Add more users as needed...
                }
                .padding(.horizontal)
            }

            Divider()

            // Row for other sharing options (like social media, SMS, etc.)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    VStack {
                        Image(systemName: "link")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        Text("Copy link")
                            .font(.caption)
                    }

                    VStack {
                        Image(systemName: "message.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        Text("Messenger")
                            .font(.caption)
                    }

                    VStack {
                        Image(systemName: "camera")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        Text("Instagram")
                            .font(.caption)
                    }

                    // Add more sharing options as needed...
                }
                .padding(.horizontal)
            }

            Spacer() // Push the content upwards
        }
        .padding(.bottom, 20) // Add padding at the bottom for spacing
        .background(Color(UIColor.systemBackground)) // Background color
        .cornerRadius(20)
    }
}

#Preview {
    SendToView()
}
