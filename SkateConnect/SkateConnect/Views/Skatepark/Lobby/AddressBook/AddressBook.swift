//
//  AddressBook.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/3/24.
//

import ConnectFramework
import CoreLocation
import NostrSDK
import SwiftData
import SwiftUI

extension Formatter {
    static let clearForZero: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.zeroSymbol  = ""
        return formatter
    }()
}

class ChannelSelectionManager: ObservableObject {
    @Published var spot: Spot?
}

struct AddressBook: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var lobby: Lobby
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network

    @Query(sort: [SortDescriptor(\Spot.updatedAt, order: .reverse)]) private var spots: [Spot]

    @StateObject private var channelSelection = ChannelSelectionManager()

    @State private var showFavoritesOnly = false
    
    @State private var name = ""
    @State private var date = Date.now
    @State private var latitude = 0.0
    @State private var longitude = 0.0
        
    var filteredSpots: [Spot] {
        spots.filter { spot in
            (!showFavoritesOnly || spot.isFavorite)
        }
    }
    
    func deleteSpot(_ spot: Spot) {
        if !spot.channelId.isEmpty {
            lobby.removeLeadByChannelId(spot.channelId)
        }
        context.delete(spot)
    }
    
    var body: some View {
        List{
            Toggle(isOn: $showFavoritesOnly) {
                Text("Favorites only")
            }
            ForEach(filteredSpots) { spot in
                
                Text("\(spot.note.contains("invite") ? "🚪" : "") \(spot.name)")
                    .contextMenu {
                        Button(action: {
                            navigation.path.removeLast()
                            navigation.tab = .map
                            
                            NotificationCenter.default.post(
                                name: .goToSpot,
                                object: spot
                            )
                        }) {
                            Text("Go to spot")
                        }
                        
                        if !spot.channelId.isEmpty {
                            Button(action: {
                                let channelId = spot.channelId
                                channelSelection.spot = spot
                                navigation.channelId = channelId
                                navigation.path.append(NavigationPathType.channel(channelId: channelId))
                            }) {
                                Text("Open chat")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = spot.channelId
                            }) {
                                Text("Copy spotId")
                            }
                        }
                        
                        Button(action: {
                            let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)

                            if let jsonString = coordinateToJSONString(coordinate) {
                                UserDefaults.standard.set(jsonString, forKey: UserDefaults.Keys.coordinates)
                            } else {
                                print("Failed to copy coordinate to clipboard")
                            }
                        }) {
                            Text("Set Home")
                        }
                        
                        Button(action: {
                            let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)

                            if let jsonString = coordinateToJSONString(coordinate) {
                                UIPasteboard.general.string = jsonString
                            } else {
                                print("Failed to copy coordinate to clipboard")
                            }
                        }) {
                            Text("Copy coordinates")
                        }
                        
                        if !spot.note.isEmpty {
                            Button(action: {
                                UIPasteboard.general.string = spot.note
                            }) {
                                Text("Copy note")
                            }
                        }
                        
                        Button(action: {
                            deleteSpot(spot)
                        }) {
                            Text("Delete")
                        }
                    }
            }
        }
    }
    
    private func readyToAdd() -> Bool {
        (!name.isEmpty)
    }
}


#Preview {
    AddressBook().modelContainer(for: Spot.self, inMemory: true)
}
