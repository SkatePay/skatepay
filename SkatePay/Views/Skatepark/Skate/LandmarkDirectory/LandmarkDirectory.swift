//
//  LandmarkDirectory.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/10/24.
//

import SwiftData
import SwiftUI

struct LandmarkDirectory: View {
        @Environment(SkatePayData.self) var modelData
        @Environment(\.modelContext) private var context
    
        @ObservedObject var navManager: NavigationManager

        @State private var showFavoritesOnly = false
        
        @State private var newName = ""
        @State private var newDate = Date.now
        @State private var newStreet = ""
        
        var filteredSpots: [Landmark] {
            modelData.landmarks.filter { landmark in
                (!showFavoritesOnly || landmark.isFavorite)
            }
        }
        
        var body: some View {
                List{
                    Toggle(isOn: $showFavoritesOnly) {
                         Text("Favorites only")
                     }
                    ForEach(filteredSpots) { landmark in
                        NavigationLink {
                            LandmarkDetail(navManager: navManager, landmark: landmark)
                        } label: {
                            LandmarkRow(landmark: landmark)
                        }
                    }
                }
                .navigationTitle("Landmarks")
                .navigationDestination(for: String.self) { route in
//                    if route == "SecondView" {
//                        SecondView(navManager: navManager)
//                    }
            }
        }
}

#Preview {
    LandmarkDirectory(navManager: NavigationManager()).modelContainer(for: Spot.self, inMemory: true)
}
