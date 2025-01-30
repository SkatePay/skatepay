//
//  LandmarkDirectory.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import SwiftData
import SwiftUI

struct LandmarkDirectory: View {
    @Environment(AppData.self) var modelData
    
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    
    @State private var showFavoritesOnly = false
    @State private var showAddPark = false

    let keychainForNostr = NostrKeychainStorage()

    var filteredSpots: [Landmark] {
        modelData.landmarks.filter { landmark in
            (!showFavoritesOnly || landmark.isFavorite)
        }
    }
    
    var body: some View {
        List {
            Toggle(isOn: $showFavoritesOnly) {
                Text("Favorites only")
            }
            ForEach(filteredSpots) { landmark in
                NavigationLink {
                    LandmarkDetail(landmark: landmark)
                        .environmentObject(navigation)
                } label: {
                    LandmarkRow(landmark: landmark)
                }
            }
            
            Button(action: {
                showAddPark.toggle()
            }) {
                Text("🛹 Add Yours")
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .fullScreenCover(isPresented: $showAddPark) {
                NavigationView {
                    DirectMessage(user: AppData().users[0], message: "request")
                        .environmentObject(dataManager)
                        .environmentObject(navigation)
                        .environmentObject(network)
                }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LandmarkDirectory().modelContainer(for: Spot.self, inMemory: true)
}
