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
import CoreLocation

struct CreateChannel: View, EventCreating {
    @Environment(\.presentationMode) var presentationMode

    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var stateManager: StateManager
    
    let keychainForNostr = NostrKeychainStorage()
        
    @State private var isShowingConfirmation = false
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = ChannelEmoji.broadcast.rawValue
    @State private var event: NostrEvent?

    
    var body: some View {
        Text("📡 Open Channel")
        Form {
            Section("Name") {
                TextField("name", text: $name)
                Text("Suggestions: My Spot, To Do, Session #7, etc.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .italic()
            }

            
            Section("Icon") {
                Picker("Select One", selection: $icon) {
                    ForEach(ChannelEmoji.allCases) { season in
                        Text(season.rawValue).tag(season)
                    }
                }
            }
            
            Section("Description") {
                TextField("description", text: $description)
            }
            Button("Create") {
                var about = description
                
                let mark = stateManager.marks[0]
                let aboutStructure = AboutStructure(description: description, location: mark.coordinate, note: icon)
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(aboutStructure)
                    about  = String(data: data, encoding: .utf8) ?? description
                } catch {
                    print("Error encoding: \(error)")
                }
                
                if let account = keychainForNostr.account {
                    do {
                        
                        let metadata = ChannelMetadata(
                            name: name,
                            about: about,
                            picture: Constants.PICTURE_RABOTA_TOKEN,
                            relays: [Constants.RELAY_URL_SKATEPARK])
                        
                        let builder = try? CreateChannelEvent.Builder().channelMetadata(metadata)
                            
                        self.event =  try builder?.build(signedBy: account)
                        
                        self.network.relayPool?.publishEvent(self.event!)

                        isShowingConfirmation = true
                        
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            .alert("Channel created", isPresented: $isShowingConfirmation) {
                Button("OK", role: .cancel) {                    
                    if let channelId = self.event?.id {
                        navigation.coordinate = stateManager.marks[0].coordinate
                        navigation.joinChannel(channelId: channelId)
                    }
                    stateManager.marks = []
                }
            }
            .disabled(!readyToSend())
        }
    }
    
    private func readyToSend() -> Bool {
        (!name.isEmpty && !description.isEmpty)
    }
}

#Preview {
    CreateChannel()
}
