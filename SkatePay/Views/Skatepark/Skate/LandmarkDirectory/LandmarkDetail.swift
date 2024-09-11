//
//  LandmarkDetail.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct LandmarkDetail: View {
    @Environment(SkatePayData.self) var modelData

    @ObservedObject var navManager: NavigationManager

    var landmark: Landmark

    var landmarkIndex: Int {
        modelData.landmarks.firstIndex(where: { $0.id == landmark.id })!
    }
    
    var body: some View {
        @Bindable var modelData = modelData

        ScrollView {
            MapView(coordinate: landmark.locationCoordinate)
                .frame(height: 300)
            
            CircleImage(image: landmark.image)
                .offset(y: -130)
                .padding(.bottom, -130)
            
            VStack(alignment: .leading) {
                HStack {
                     Text(landmark.name)
                         .font(.title)
                     FavoriteButton(isSet: $modelData.landmarks[landmarkIndex].isFavorite)
                 }
                
                HStack {
                    Text(landmark.address)
                    Spacer()
                    Text(landmark.state)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                Button(action: {
                    print("visit")
                    navManager.landmark = landmark
                    navManager.dismissToContentView()
                }) {
                    Text("Visit")
                }
                Divider()
                
                Text("About")
                    .font(.title2)
                Text(landmark.description)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle(landmark.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let modelData = SkatePayData()
    return LandmarkDetail(navManager: NavigationManager(), landmark: modelData.landmarks[0])
        .environment(modelData)
}
