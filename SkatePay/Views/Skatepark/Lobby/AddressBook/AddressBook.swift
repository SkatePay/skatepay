//
//  AddressBook.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/3/24.
//

import SwiftUI
import SwiftData
import NostrSDK

struct AddressBook: View {
    @Query private var spots: [Spot]
    @State private var showFavoritesOnly = false
    
    @Environment(\.modelContext) private var context
    
    @State private var newName = ""
    @State private var newDate = Date.now
    @State private var newNPub = ""
    
    
    var filteredSpots: [Spot] {
        spots.filter { spot in
            (!showFavoritesOnly || spot.isFavorite)
        }
    }
    
    var body: some View {
        NavigationStack {
            List{
                Toggle(isOn: $showFavoritesOnly) {
                     Text("Favorites only")
                 }
                ForEach(filteredSpots) { spot in
                    NavigationLink {
                        SpotDetail(spot: spot)
                    } label: {
                        SpotRow(spot: spot)
                    }
                }
            }
            .navigationTitle("Spots")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 20) {
                    Text("New Spot")
                        .font(.headline)
                    DatePicker(selection: $newDate, in: Date.distantPast...Date.now, displayedComponents: .date) {
                        TextField("Name", text: $newName)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("Street", text: $newNPub)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        let newFriend = Friend(npub: newNPub, name: newName, birthday: newDate, note: "")
                        context.insert(newFriend)
                    }
                    .bold()
                }
                .padding()
                .background(.bar)
            }
            .task {
                let spots = ModelData().landmarks
                context.insert(Spot(name: spots[0].name, address: spots[0].address, state: spots[0].state, note: spots[0].description, isFavorite: true,  latitude: spots[0].locationCoordinate.latitude, longitude: spots[0].locationCoordinate.longitude, imageName: "venice-skate-park"))
                context.insert(Spot(name: spots[1].name, address: spots[1].address, state: spots[1].state, note: spots[1].description, latitude: spots[1].locationCoordinate.latitude, longitude: spots[1].locationCoordinate.longitude, imageName: "inglewood-pumptrack"))
                context.insert(Spot(name: spots[2].name, address: spots[2].address, state: spots[2].state, note: spots[0].description, latitude: spots[2].locationCoordinate.latitude, longitude: spots[2].locationCoordinate.longitude, imageName: "channel-street-skatepark"))
            }
        }
    }
}


#Preview {
    AddressBook().modelContainer(for: Spot.self, inMemory: true)
}
