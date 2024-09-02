//
//  MockChat.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import SwiftUI

import Foundation
import SwiftUI
import ExyteChat

struct MockChat: View {
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var feed: MockFeed
    
    private let title: String

    init(feed: MockFeed = MockFeed(), title: String) {
        _feed = StateObject(wrappedValue: feed)
        self.title = title
    }
    
    var body: some View {
        ChatView(messages: feed.messages, chatType: .conversation) { draft in
            feed.send(draft: draft)
        }
        .enableLoadMore(pageSize: 3) { message in
            feed.loadMoreMessage(before: message)
        }
        .messageUseMarkdown(messageUseMarkdown: true)
        .navigationBarBackButtonHidden()
        .toolbar{
            ToolbarItem(placement: .navigationBarLeading) {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    Image("backArrow", bundle: .current)
                }
            }
            
            ToolbarItem(placement: .principal) {
                HStack {
                    if let url = feed.chatCover {
                        CachedAsyncImage(url: url, urlCache: .shared) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "AFB3B8"))
                            }
                        }
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(feed.chatTitle)
                            .fontWeight(.semibold)
                            .font(.headline)
                            .foregroundColor(.black)
                        Text(feed.chatStatus)
                            .font(.footnote)
                            .foregroundColor(Color(hex: "AFB3B8"))
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
        }
        .onAppear(perform: feed.onStart)
        .onDisappear(perform: feed.onStop)
    }
}

#Preview {
    MockChat(title: "Chat")
}
