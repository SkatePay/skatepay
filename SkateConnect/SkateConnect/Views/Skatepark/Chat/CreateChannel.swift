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

func createLead(from event: NostrEvent) -> Lead? {
    var lead: Lead?
    
    if let channel = parseChannel(from: event.content) {
        let about = channel.about
        
        do {
            let decoder = JSONDecoder()
            let decodedStructure = try decoder.decode(AboutStructure.self, from: about.data(using: .utf8)!)
            
            var icon = "📺"
            if let note = decodedStructure.note {
                icon = note
            }
            
            lead = Lead(
                name: channel.name,
                icon: icon,
                coordinate: decodedStructure.location,
                channelId: event.id,
                event: event,
                channel: channel
            )
        } catch {
            print("Error decoding: \(error)")
        }
    }
    return lead
}

struct CreateChannel: View, EventCreating {    
    @ObservedObject var networkConnections = Network.shared
    
    let keychainForNostr = NostrKeychainStorage()
    
    @ObservedObject var navigation = Navigation.shared
    
    @State private var isShowingConfirmation = false
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = ChannelType.broadcast.rawValue
    
    private var relayPool: RelayPool {
        return networkConnections.getRelayPool()
    }
    
    private var mark: Mark?
    
    init(mark: Mark? = nil) {
        self.mark = mark
    }
    
    var body: some View {
        Text("📡 Create Channel")
        Form {
            Section("Name") {
                TextField("name", text: $name)
            }
            
            Section("Icon") {
                Picker("Select One", selection: $icon) {
                    ForEach(ChannelType.allCases) { season in
                        Text(season.rawValue).tag(season)
                    }
                }
            }
            
            Section("Description") {
                TextField("description", text: $description)
            }
            Button("Create") {
                var about = description
                
                if let mark = mark {
                    let aboutStructure = AboutStructure(description: description, location: mark.coordinate, note: icon)
                    do {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = .prettyPrinted
                        let data = try encoder.encode(aboutStructure)
                        about  = String(data: data, encoding: .utf8) ?? description
                    } catch {
                        print("Error encoding: \(error)")
                    }
                }
                
                if let account = keychainForNostr.account {
                    do {
                        
                        let metadata = ChannelMetadata(
                            name: name,
                            about: about,
                            picture: Constants.PICTURE_RABOTA_TOKEN,
                            relays: [Constants.RELAY_URL_PRIMAL])
                        
                        let builder = try? CreateChannelEvent.Builder().channelMetadata(metadata)
                            
                        let event =  try builder?.build(signedBy: account)
                        
                        relayPool.publishEvent(event!)

                        isShowingConfirmation = true
                        
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
        (!name.isEmpty && !description.isEmpty)
    }
}

#Preview {
    CreateChannel()
}
