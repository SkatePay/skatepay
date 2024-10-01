//
//  LandmarkDetail.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct LandmarkDetail: View {
    @Environment(AppData.self) var modelData

    @ObservedObject var navigation = Navigation.shared

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
                
                HStack(spacing: 20) {
                    Spacer()
                    Button(action: {
                        navigation.landmark = landmark
                        navigation.dismissToContentView()
                    }) {
                        Text("🎟️ Visit")
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
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
    let modelData = AppData()
    return LandmarkDetail(landmark: modelData.landmarks[0])
        .environment(modelData)
}
