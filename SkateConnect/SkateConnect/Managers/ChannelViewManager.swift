//
//  ChannelManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/8/24.
//

import Foundation
import SwiftUI

@MainActor
class ChannelViewManager: ObservableObject {
    @Published private var navigation: Navigation?
    @Published private var network: Network?
    
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    func setNetwork(network: Network) {
        self.network = network
    }
    
    func openChannel(channelId: String, invite: Bool = false) {
        network?.subscribeToChannelWhenReady(channelId)
        navigation?.channelId = channelId
        navigation?.path.append(
            NavigationPathType.channel(channelId: channelId, invite: invite)
        )
    }

    func closeChannel() {
        navigation?.channelId = nil
    }
    
    func deleteChannelWithId(_ channelId: String) {
        network?.publishDeleteEventForChannel(channelId)
    }
}
