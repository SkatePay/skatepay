//
//  OverlayView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/26/25.
//

import Combine
import ConnectFramework
import MapKit
import NostrSDK
import SwiftData
import SwiftUI

struct OverlayView: View {
    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var apiService: API
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    
    @Binding var isInviteCopied: Bool
    @Binding var isLinkCopied: Bool
    
    var body: some View {
        ZStack {
            TickerOverlay()
                .environmentObject(apiService)
                .environmentObject(network)
                .environmentObject(stateManager)
            ConsoleOverlay()
                .environmentObject(stateManager)
            NotificationOverlay(
                isInviteCopied: $isInviteCopied,
                isLinkCopied: $isLinkCopied
            )
            MarkControls()
        }
        .animation(.easeInOut, value: isInviteCopied)
    }
}
