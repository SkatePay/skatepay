//
//  ChannelManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation

class ChannelManager: ObservableObject {
    @Published var isShowingChannelView = false
    @Published var channelId: String = ""

    init() {
        print("ChannelManager initialized")
    }
    
    func openChannel(channelId: String) {
        self.channelId = channelId
        self.isShowingChannelView = true
        
//        NotificationCenter.default.post(
//            name: .joinChannel,
//            object: self,
//            userInfo: ["channelId": channelId]
//        )
    }

    func closeChannel() {
        self.isShowingChannelView = false
        self.channelId = ""
    }
}
