//
//  SpotDetail.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/4/24.
//

import SwiftUI
import SwiftData

struct SpotDetail: View {
    @Environment(AppData.self) var modelData
    @Query private var spots: [Spot]
    
    var spot: Spot
    
    var body: some View {
        @Bindable var modelData = modelData

        ScrollView {
            MapView(coordinate: spot.locationCoordinate)
                .frame(height: 300)
            
            CircleImage(image: spot.image)
                .offset(y: -130)
                .padding(.bottom, -130)
            
            VStack(alignment: .leading) {
                HStack {
                     Text(spot.name)
                         .font(.title)
                     // FavoriteButton(isSet: $modelData.landmarks[landmarkIndex].isFavorite)
                 }
                
                HStack {
                    Text(spot.address)
                    Spacer()
                    Text(spot.state)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                Divider()
                
                Text("About")
                    .font(.title2)
                Text(spot.note)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let data = AppData()
    let spots = AppData().landmarks;

    return SpotDetail(spot: Spot(name: spots[0].name, address: spots[0].address, state: spots[0].state, note: ""))
        .environment(data)
}
