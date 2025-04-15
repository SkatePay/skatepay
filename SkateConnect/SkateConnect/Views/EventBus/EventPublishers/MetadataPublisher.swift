//
//  MetadataPublisher.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/12/25.
//

import os

import Combine
import Foundation
import MessageKit
import NostrSDK

@MainActor
class MetadataPublisher: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "MetadataPublisher")
    
    public func subscribeFor(_ publicKey: PublicKey) {
        os_log("⏳ requesting subscription to metadata for [%{public}@]", log: log, type: .info, publicKey.npub)

        EventBus.shared.didReceiveMetadataSubscriptionRequest.send(publicKey)
    }
}
