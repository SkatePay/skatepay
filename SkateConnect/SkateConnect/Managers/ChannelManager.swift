//
//  ChannelManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation
import SwiftUI

class ChannelManager: ObservableObject {
    @ObservedObject var network = Network.shared

    @Published var isShowingChannelView = false
    @Published var channelId: String = ""
    
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
    
    func deleteChannelWithId(_ channelId: String) {
        network.submitDeleteChannelRequestForChannelId(channelId)
    }
}
