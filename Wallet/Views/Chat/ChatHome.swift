//
//  ChatHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK
import Combine

struct ChatHome: View {

    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = ""
    @State private var events: [NostrEvent] = []
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?

    @AppStorage("filter") var filter: String = ""

    private let kindOptions = [
        0: "Set Metadata",
        1: "Text Note",
        3: "Follow List",
        4: "Ecrypted Direct Message",
        6: "Repost",
        7: "Reaction",
        1984: "Report",
        10000: "Mute List",
        10003: "Bookmarks List",
        30023: "Longform Content"
    ]

    @State private var selectedKind = 1

    var body: some View {
        Form {
            Section("Query Relays") {

                TextField(text: $authorPubkey) {
                    Text("Author Public Key (nsub)")
                }

                Picker("Kind", selection: $selectedKind) {
                    ForEach(kindOptions.keys.sorted(), id: \.self) { number in
                        if let name = kindOptions[number] {
                            Text("\(name) (\(String(number)))")
                        } else {
                            Text("\(String(number))")
                        }
                    }
                }
            }

            Button {
                updateSubscription()
            } label: {
                Text("Query")
            }

            if !events.isEmpty {
                Section("Results") {
                    if !authorPubkey.isEmpty {
                        Text("Note: send an event from this account and see it appear here.")
                            .foregroundColor(.gray)
                            .font(.footnote)
                    }
                    List(events, id: \.id) { event in
                        if !event.content.isEmpty {
                            Text("\(event.content)")
                        } else {
                            // Text("Empty content field for event \(event.id)")
                        }
                    }
                }
            }
        }
        .onChange(of: authorPubkey) {
            events = []
            updateSubscription()
        }
        .onChange(of: selectedKind) {
            events = []
            updateSubscription()
        }
        .onDisappear {
            if let subscriptionId {
                relayPool.closeSubscription(with: subscriptionId)
            }
        }
    }
    
    private var currentFilter: Filter {
        let authors: [String]?
        
        let author = PublicKey(npub: authorPubkey)?.hex ?? filter
        
        if authorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [author]
        }
        return Filter(authors: authors, kinds: [selectedKind])!
    }
    
    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }
        
        subscriptionId = relayPool.subscribe(with: currentFilter)
        
        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                $0.event
            }
            .removeDuplicates()
            .sink { event in
                events.insert(event, at: 0)
            }
    }
}

#Preview {
    ChatHome()
}
