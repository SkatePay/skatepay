//
//  MarkerOptions.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import Combine
import NostrSDK
import SwiftUI

class MarkerOptionsModel: ObservableObject {
    @Published var showEditChannel = false
}

struct MarkerOptions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: ContentViewModel
    
    @StateObject private var markerOptionsModel = MarkerOptionsModel()
    
    @State private var showCreateChannel = false
    @State private var showChannelView = false
    
    var npub: String?
    var marks: [Mark]
    
    let keychainForNostr = NostrKeychainStorage()
    
    var landmarks: [Landmark] = AppData().landmarks
    
    func getLandmark() -> Landmark? {
        return landmarks.first { $0.npub == npub }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Marker Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                showChannelView = true
            }) {
                Text("Join Official Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                showCreateChannel = true
            }) {
                Text("Start New Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                for mark in marks {
                    let spot = Spot(name: mark.name, address: "", state: "", note: "", latitude: mark.coordinate.latitude, longitude: mark.coordinate.longitude)
                    context.insert(spot)
                }
                
                dismiss()
            }) {
                Text("Add to Address Book")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .onAppear{
            updateSubscription()
        }
        .onDisappear{
            if let subscriptionId {
                viewModel.relayPool.closeSubscription(with: subscriptionId)
            }
        }
        .fullScreenCover(isPresented: $showChannelView) {
            if let landmark = getLandmark() {
                NavigationView {
                    ChannelFeed(eventId: landmark.eventId)
                }
            }
        }
        .fullScreenCover(isPresented: $showCreateChannel) {
            NavigationView {
                CreateChannel()
                    .navigationBarItems(leading:
                                            Button(action: {
                        showCreateChannel = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Spacer()
                        }
                    })
            }
        }
        .padding()
    }
    
    // Nostr
    @State private var subscriptionId: String?
    @State var fetchingStoredEvents = true
    @State private var eventsCancellable: AnyCancellable?
    @ObservedObject var chatDelegate = ChatDelegate()

    private var currentFilter: Filter? {
        guard let account = keychainForNostr.account else {
            print("Error: Failed to create Filter")
            return nil
        }
        
        let authors = [account.publicKey.hex]
        
        return Filter(authors: authors, kinds: [EventKind.channelCreation.rawValue, EventKind.channelMetadata.rawValue])
    }
    
    private func updateSubscription() {
        if let subscriptionId {
            viewModel.relayPool.closeSubscription(with: subscriptionId)
        }
        
        if let unwrappedFilter = currentFilter {
            subscriptionId = viewModel.relayPool.subscribe(with: unwrappedFilter)
        } else {
            print("currentFilter is nil, unable to subscribe")
        }
        viewModel.relayPool.delegate = chatDelegate
                
        eventsCancellable = viewModel.relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                return $0.event
            }
            .removeDuplicates()
            .sink { event in
//                print(event)
            }
    }
}
#Preview {
    MarkerOptions(npub: "", marks: [])
}
