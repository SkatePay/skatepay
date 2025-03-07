//
//  MessageHandler.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/7/24.
//

import Combine
import ConnectFramework
import Foundation
import MessageKit
import NostrSDK
import UIKit

class MessageHandler: ObservableObject {
    @Published var messages: [MessageType] = []
}
