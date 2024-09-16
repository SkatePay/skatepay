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
    
    @ObservedObject var navigation = NavigationManager.shared

    @State private var showFavoritesOnly = false
    
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
                } label: {
                    LandmarkRow(landmark: landmark)
                }
            }
        }
    }
}

#Preview {
    LandmarkDirectory().modelContainer(for: Spot.self, inMemory: true)
}
