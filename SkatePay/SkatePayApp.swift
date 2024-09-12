//
//  SkatePayApp.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/6/24.
//

import NostrSDK
import SwiftUI
import SwiftData

@main
struct SkatePayApp: App {
    @State private var modelData = AppData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Friend.self, Spot.self])
                .environment(modelData)
        }
    }
}
