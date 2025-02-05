//
//  EventServiceForDirect.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 2/5/25.
//

import ConnectFramework
import Foundation
import NostrSDK
import Combine

class EventServiceForDirect: ObservableObject, EventCreating {
    @Published var fetchingStoredEvents = true
    
    private var network: Network?

    public var subscriptionIdForPrivateMessages: String?
    
    init(network: Network) {
        self.network = network
    }
}
