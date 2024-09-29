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
    
    @AppStorage("hasAcknowledgedEULA") private var hasAcknowledgedEULA = false
    
    var body: some Scene {
        WindowGroup {
            if hasAcknowledgedEULA {
                ContentView()
                    .modelContainer(for: [Friend.self, Foe.self, Spot.self], inMemory: false)
                    .environment(modelData)
            } else {
                EULAView(hasAcknowledgedEULA: $hasAcknowledgedEULA)
                
            }
        }
    }
}
