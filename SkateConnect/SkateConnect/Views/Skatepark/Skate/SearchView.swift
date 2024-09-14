//
//  SearchView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/13/24.
//

import ConnectFramework
import CoreLocation
import SwiftData
import SwiftUI

struct SearchView: View {
    @ObservedObject var navigation: NavigationManager

    @Query private var spots: [Spot]

    @State private var coordinateString: String = ""
    @State private var channelId: String = ""
    
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section("coordinates") {
                TextField("{ \"latitude\": 0.0, \"longitude\": 0.0 }", text: $coordinateString)
            }
            Section("channel") {
                TextField("channel", text: $channelId)
            }
            Button("Search") {
                showingAlert.toggle()
            }
            .alert("Start search.", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if (!coordinateString.isEmpty) {
                        navigation.coordinates = convertStringToCoordinate(coordinateString)
                    }
                    
                    if (!channelId.isEmpty) {
                        let spot = findSpotByChannelId(channelId)
                        
                        if let coordinates = spot?.locationCoordinate {
                            navigation.coordinates = coordinates
                        }
                    }
                    navigation.recoverFromSearch()
                }
            }
            .disabled(!readyToSend())
        }
    }
    
    func findSpotByChannelId(_ channelId: String) -> Spot? {
        return spots.first { $0.channelId == channelId }
    }
    
    private func readyToSend() -> Bool {
        (!coordinateString.isEmpty || !channelId.isEmpty)
    }
}

#Preview {
    SearchView(navigation: NavigationManager())
}
