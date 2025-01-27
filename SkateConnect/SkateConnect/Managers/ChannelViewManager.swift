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

    @Published private var network: Network?
    
    @Published var isShowingChannelView = false
    
    @Published var channelId: String?
    
    init() {
        print("ChannelViewManager initialized at \(Date())")
    }
    
    func setNetwork(network: Network) {
        self.network = network
    }
    func openChannel(channelId: String) {
        guard self.channelId != channelId || !self.isShowingChannelView else {
            print("Channel already open: \(channelId)")
            return
        }
        
        self.channelId = channelId
        self.isShowingChannelView = true
        
        print("Open Channel triggered for ID:", channelId)
    }

    func closeChannel() {
        self.isShowingChannelView = false
        self.channelId = nil
    }
    
    func deleteChannelWithId(_ channelId: String) {
        network?.submitDeleteChannelRequestForChannelId(channelId)
    }
}
