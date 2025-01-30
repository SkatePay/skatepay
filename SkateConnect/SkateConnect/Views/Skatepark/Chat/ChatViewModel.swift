//
//  ChatViewModel.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/18/24.
//

import MessageKit
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var firstMessagesOfDay: [IndexPath: Date] = [:]
    @Published var messages: [MessageType] = []

    func updateFirstMessagesOfDay(_ messages: [MessageType]) {
        firstMessagesOfDay.removeAll()
        var lastDate: Date?

        for (index, message) in messages.enumerated() {
            let messageDate = Calendar.current.startOfDay(for: message.sentDate)

            if lastDate == nil || lastDate != messageDate {
                let indexPath = IndexPath(item: 0, section: index)
                firstMessagesOfDay[indexPath] = messageDate
            }

            lastDate = messageDate
        }
    }
}
