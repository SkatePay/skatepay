//
//  NotesPublisher.swift
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
class NotesPublisher: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "NotesPublisher")
    
    public func subscribeToNotesWithPublicKey(_ publicKey: PublicKey) {
        os_log("⏳ requesting subscription to notes for [%{public}@]", log: log, type: .info, publicKey.npub)

        EventBus.shared.didReceiveNotesSubscriptionRequest.send(publicKey)
    }
}
