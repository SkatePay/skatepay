//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import SwiftUI

@main
struct SkateConnectApp: App {
    @State private var modelData = AppData()
    
    @ObservedObject var navigation = Navigation.shared
    
    var body: some Scene {
        WindowGroup {
            if (navigation.hasAcknowledgedEULA) {
                ContentView()
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self], inMemory: false)
                    .environment(modelData)
            } else {
                EULAView()
            }
        }
    }
}
