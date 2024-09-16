//
//  CreateChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/11/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI
import SwiftData

struct Channel: Codable {
    let name: String
    let about: String
    let picture: String
    let relays: [String]
}

func parseChannel(from jsonString: String) -> Channel? {
    guard let data = jsonString.data(using: .utf8) else {
        print("Failed to convert string to data")
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        let channel = try decoder.decode(Channel.self, from: data)
        return channel
    } catch {
        print("Error decoding JSON: \(error)")
        return nil
    }
}

func encodeChannel(_ channel: Channel) -> String? {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For a more readable JSON output
        let data = try encoder.encode(channel)
        return String(data: data, encoding: .utf8)
    } catch {
        print("Error encoding channel: \(error)")
        return nil
    }
}

struct CreateChannel: View, EventCreating {
    @EnvironmentObject var viewModel: ContentViewModel
    
    @ObservedObject var networkConnections = NetworkConnections.shared

    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var navigation = NavigationManager.shared

    @State private var isShowingConfirmation = false
    
    @State private var name: String = ""
    @State private var about: String = ""
        
    var body: some View {
        Text("📡 Create Channel")
        Form {
            Section("Name") {
                TextField("name", text: $name)
            }
            Section("About") {
                TextField("about", text: $about)
            }
            Button("Create") {
                if let account = keychainForNostr.account {
                    do {
                        let channel = Channel(
                            name: name,
                            about: about,
                            picture: Constants.PICTURE_RABOTA_TOKEN,
                            relays: [Constants.RELAY_URL_PRIMAL]
                        )
                        
                        if let content = encodeChannel(channel) {
                            let event = try createChannelEvent(withContent: content, signedBy: account)
                            
                            networkConnections.reconnectRelaysIfNeeded()
                            networkConnections.relayPool.publishEvent(event)
                            
                            isShowingConfirmation = true
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            .alert("Channel created", isPresented: $isShowingConfirmation) {
                Button("OK", role: .cancel) {
                    navigation.dismissToSkateView()
                }
            }
            .disabled(!readyToSend())
        }
    }
    
    private func readyToSend() -> Bool {
        (!name.isEmpty && !about.isEmpty)
    }
}

#Preview {
    CreateChannel()
}
