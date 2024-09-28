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
    @ObservedObject var navigation = Navigation.shared

    @Query private var spots: [Spot]

    @State private var coordinateString: String = ""
    @State private var channelId: String = ""
    
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section("channel") {
                TextField("channel", text: $channelId)
            }
            
            Section("coordinates") {
                TextField("{ \"latitude\": 0.0, \"longitude\": 0.0 }", text: $coordinateString)
            }
            Button("Search") {
                showingAlert.toggle()
            }
            .alert("Start search.", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    if (!coordinateString.isEmpty) {
                        navigation.coordinate = convertStringToCoordinate(coordinateString)
                        navigation.recoverFromSearch()
                        return
                    }
                    
                    if (!channelId.isEmpty) {
                        let spot = findSpotByChannelId(channelId)
                        
                        if let coordinates = spot?.locationCoordinate {
                            navigation.coordinate = coordinates
                        }
                        
                        navigation.joinChat(channelId: channelId)
                    }
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
    SearchView()
}
