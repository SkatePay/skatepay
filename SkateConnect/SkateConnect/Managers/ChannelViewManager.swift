//
//  ChannelManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import os

import Foundation
import SwiftUI

@MainActor
class ChannelViewManager: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "ChannelViewManager")

    @Published private var navigation: Navigation?
    @Published private var network: Network?
    
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    func setNetwork(network: Network) {
        self.network = network
    }
    
    func openChannel(channelId: String, invite: Bool = false, deeplink: Bool = false) {
//        if (deeplink || invite) {
//            network?.subscribeToChannelCreationWhenReady(channelId)
//            network?.subscribeToChannelMessagesWhenReady(channelId)
//        }
        
        navigation?.channelId = channelId
        
        if (!UserDefaults.standard.bool(forKey: UserDefaults.Keys.hasAcknowledgedEULA)) {
            os_log("⏳ waiting for user to acknowledge EULA", log: log, type: .info)
            network?.setCachedChannelId(channelId)
            return
        }
        
        navigation?.path.append(
            NavigationPathType.channel(channelId: channelId, invite: invite || deeplink)
        )
    }

    func deleteChannelWithId(_ channelId: String) {
        network?.publishDeleteEventForChannel(channelId)
    }
}
