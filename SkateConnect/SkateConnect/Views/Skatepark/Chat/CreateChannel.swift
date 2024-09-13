//
//  CreateChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/11/24.
//

import SwiftUI
import SwiftData
import NostrSDK

struct CreateChannel: View, EventCreating {
    @EnvironmentObject var viewModel: ContentViewModel
    
    let keychainForNostr = NostrKeychainStorage()
    
    @State private var showingAlert = false
    
    @State private var name: String = ""
    @State private var about: String = ""
    
    var body: some View {
        Text("Create Channel")
        Form {
            Section("Name") {
                TextField("name", text: $name)
            }
            Section("About") {
                TextField("about", text: $about)
            }
            Button("Send") {
                if let account = keychainForNostr.account {
                    do {
                        let content = "{\"name\": \"Demo Channel\", \"about\": \"A test channel.\", \"picture\": \"https://placekitten.com/200/200\", \"relays\": [\"wss://relay.primal.net\"]}"

                        let event = try createChannelEvent(withContent: content, signedBy: account)
                        
                        viewModel.relayPool.publishEvent(event)
                        showingAlert = true
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            .alert("Channel created", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
//            .disabled(!readyToSend())
        }
    }
    
    private func readyToSend() -> Bool {
        (!name.isEmpty && !about.isEmpty)
    }
}

#Preview {
    CreateChannel()
}
