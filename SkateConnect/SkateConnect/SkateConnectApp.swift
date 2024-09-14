//
//  SkateConnectApp.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI
import SwiftData


class AppConnections: ObservableObject {
    // swiftlint:disable:next force_try
    @Published var relayPool = try! RelayPool(relayURLs: [
        URL(string: Constants.RELAY_URL_PRIMAL)!
    ])
}

@main
struct SkateConnectApp: App {
    @State private var modelData = AppData()
    
    @ObservedObject var appConnections = AppConnections()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Friend.self, Foe.self, Spot.self])
                .environment(modelData)
                .environmentObject(appConnections)
        }
    }
}
