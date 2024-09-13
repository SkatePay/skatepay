//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import NostrSDK
import SwiftUI
import SwiftData

@main
struct SkateConnectApp: App {
    @State private var modelData = AppData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Friend.self, Foe.self, Spot.self])
                .environment(modelData)
        }
    }
}
