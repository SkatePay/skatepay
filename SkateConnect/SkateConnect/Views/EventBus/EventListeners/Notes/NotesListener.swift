//
//  NotesListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/1/25.
//

import Combine
import Foundation
import MessageKit
import NostrSDK
import os

enum NoteType {
    case deck(SkateboardDeck)
    case unknown // Or other message types you handle
}

class NotesListener: ObservableObject, EventCreating {
    private let log = OSLog(subsystem: "SkateConnect", category: "EventProcessing")

    @Published var notesFromDeckTracker: [NoteType] = []
    @Published var receivedEOSE = false
    @Published var timestamp = Int64(0)
    
    private var dataManager: DataManager?
    private var debugManager: DebugManager?
    private var account: Keypair?
    
    var publicKey: PublicKey?
    var subscriptionId: String?
    
    
    public var cancellables = Set<AnyCancellable>()
    
    private let deckTrackerNoteKind = "DeckTracker"
    
    init() {

        EventBus.shared.didReceiveNotesSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (publicKey, subscriptionId) in
                
                if (self?.publicKey != publicKey) {
                    return
                }
                
                self?.subscriptionId = subscriptionId
                os_log("🔄 didReceiveNotesSubscription: %{public}@", log: self?.log ?? .default, type: .info, subscriptionId)
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveEOSE
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                
                guard case .eose(let subscriptionId) = response else {
                    return
                }
                
                if (self?.subscriptionId != subscriptionId) {
                    return
                }
                
                if let log = self?.log {
                    os_log("📡 EOSE received: %{public}@", log: log, type: .info, subscriptionId)
                }
                
                self?.receivedEOSE = true
            }
            .store(in: &cancellables)
        
        EventBus.shared.didReceiveNote
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.processNote(event.event)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        guard let subscriptionId = self.subscriptionId else {
            os_log("🔥 failed to get subscriptionId", log: log, type: .error)
            return
        }
        
        EventBus.shared.didReceiveCloseSubscriptionRequest.send(subscriptionId)
    }
    
    func setPublicKey(_ publicKey: PublicKey) {
        self.publicKey = publicKey
    }
    
    func setDependencies(dataManager: DataManager, debugManager: DebugManager, account: Keypair) {
        self.dataManager = dataManager
        self.debugManager = debugManager
        self.account = account
    }
    
    private func processEventIntoNote(_ event: NostrEvent) -> NoteType? {
        os_log("⏳ Processing event content: %@", log: log, type: .debug, event.content)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let noteData = event.content.data(using: .utf8) else {
            os_log("❌ Failed to convert event content string to Data", log: log, type: .error)
            return nil
        }

        let note: Note
        do {
            note = try decoder.decode(Note.self, from: noteData)
        } catch {
            os_log("❌ Failed to decode outer Note JSON: %@", log: log, type: .error, String(describing: error))
            return nil
        }

        guard note.kind == deckTrackerNoteKind else {
            os_log("⏩ Skipping event: Note kind is '%@', expected '%@'", log: log, type: .debug, note.kind, deckTrackerNoteKind)
            return nil
        }
        
        guard let deckData = note.text.data(using: .utf8) else {
            os_log("❌ Failed to convert note text string (deck JSON) to Data", log: log, type: .error)
            return nil
        }

        do {
            let skateboardDeck = try decoder.decode(SkateboardDeck.self, from: deckData)
            os_log("✔️ Successfully decoded SkateboardDeck: Name '%@', Width %.3f", log: log, type: .info, skateboardDeck.name, skateboardDeck.width)
            return .deck(skateboardDeck)

        } catch {
            os_log("❌ Failed to decode inner SkateboardDeck JSON: %@", log: log, type: .error, String(describing: error))
            return nil
        }
    }
    
    private func processNote(_ event: NostrEvent) {
        if let note = processEventIntoNote(event) {
            if (self.receivedEOSE) {
                timestamp = event.createdAt
//                notesFromDeckTracker.append(message)
            } else {
                notesFromDeckTracker.insert(note, at: 0)
            }
        }
    }
    
    func reset() {
        notesFromDeckTracker.removeAll()
        receivedEOSE = false
    }
}
