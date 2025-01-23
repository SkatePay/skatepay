//
//  ChannelManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation
import SwiftUI

class ChannelViewManager: ObservableObject {
    static let shared = ChannelViewManager()

    @ObservedObject var network = Network.shared

    @Published var isShowingChannelView = false {
        didSet {
            print("isShowingChannelView updated to: \(isShowingChannelView)")
        }
    }
    
    @Published var channelId: String?
    
    init() {
        print("ChannelViewManager initialized at \(Date())")
    }
    
    func openChannel(channelId: String) {
        guard self.channelId != channelId || !self.isShowingChannelView else {
            print("Channel already open: \(channelId)")
            return
        }
        
        self.channelId = channelId
        self.isShowingChannelView = true
    }

    func closeChannel() {
        self.isShowingChannelView = false
        self.channelId = nil
    }
    
    func deleteChannelWithId(_ channelId: String) {
        network.submitDeleteChannelRequestForChannelId(channelId)
    }
}
