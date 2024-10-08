//
//  AddressBook.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/3/24.
//

import SwiftUI
import SwiftData
import NostrSDK

extension Formatter {
    static let clearForZero: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.zeroSymbol  = ""
        return formatter
    }()
}

struct AddressBook: View {
    @Environment(\.modelContext) private var context
    
    @Query private var spots: [Spot]
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
    
    var body: some View {
        NavigationStack {
            List{
                Toggle(isOn: $showFavoritesOnly) {
                    Text("Favorites only")
                }
                ForEach(filteredSpots) { spot in
                    
                    Text(spot.name)
                        .contextMenu {
                            Button(action: {
                                context.delete(spot)
                            }) {
                                Text("Delete")
                            }
                        }
                }
            }
            .navigationTitle("Spots")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 20) {
                    Text("New Spot")
                        .font(.headline)
                    DatePicker(selection: $date, in: Date.distantPast...Date.now, displayedComponents: .date) {
                        TextField("name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("latitude", value: $latitude, formatter: Formatter.clearForZero)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("longitude", value: $longitude, formatter: Formatter.clearForZero)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        let spot = Spot(name: name, address: "", state: "", note: "", latitude: latitude, longitude: longitude)
                        context.insert(spot)
                    }
                    .bold()
                }
                .padding()
                .background(.bar)
            }
            //            .task {
            //                do {
            //                    try context.delete(model: Spot.self)
            //                } catch {
            //                    print("Failed to delete all spots.")
            //                }
            //            }
        }
    }
}


#Preview {
    AddressBook().modelContainer(for: Spot.self, inMemory: true)
}
