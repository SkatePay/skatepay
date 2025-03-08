//
//  DMEventPublisher.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/7/25.
//

import os

import Combine
import Foundation
import MessageKit
import NostrSDK

@MainActor
class DMEventPublisher: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "DMEventPublisher")
    
    public func subscribeToUserWithPublicKey(_ publicKey: PublicKey) {
        os_log("⏳ requesting subscription to user [%{public}@]", log: log, type: .info, publicKey.npub)

        EventBus.shared.didReceiveDMSubscriptionRequest.send(publicKey)
    }
}
