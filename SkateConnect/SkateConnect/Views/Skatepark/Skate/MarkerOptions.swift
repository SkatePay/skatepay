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
    
    @ObservedObject var navigation: NavigationManager

    @StateObject private var markerOptionsModel = MarkerOptionsModel()
        
    var marks: [Mark]
    
    let keychainForNostr = NostrKeychainStorage()
    
    var landmarks: [Landmark] = AppData().landmarks
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Marker Options")
                .font(.title2)
                .padding()
            
            Button(action: {
                navigation.isShowingCreateChannel = true
                viewModel.mark = marks[0]
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
        .fullScreenCover(isPresented: $navigation.isShowingCreateChannel) {
            NavigationView {
                CreateChannel(navigation: navigation)
                    .navigationBarItems(leading:
                    Button(action: {
                        navigation.isShowingCreateChannel = false
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
    MarkerOptions(navigation: NavigationManager(), marks: [])
}
