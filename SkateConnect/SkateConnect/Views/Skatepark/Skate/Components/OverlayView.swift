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
            GeometryReader { geometry in
                if stateManager.isShowingLoadingOverlay {
                    HStack {
                        MarqueeText(text: debugOutput())
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                stateManager.isShowingLoadingOverlay = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: 16)
                }
                
                if isInviteCopied {
                    Text("Invite copied! Paste in DM or a channel.")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .zIndex(1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isInviteCopied = false
                                }
                            }
                        }
                }
                
                if isLinkCopied {
                    Text("Link copied. Share it with friends!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .zIndex(1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isLinkCopied = false
                                }
                            }
                        }
                }
            }
            
            if !stateManager.marks.isEmpty {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        HStack {
                            Text("Start Channel")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                navigation.path.append(NavigationPathType.createChannel)
                            }) {
                                Image(systemName: "shareplay")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Text("Save Spot")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                Task {
                                    for mark in stateManager.marks {
                                        let spot = Spot(
                                            name: mark.name,
                                            address: "",
                                            state: "",
                                            icon: "",
                                            note: "private",
                                            latitude: mark.coordinate.latitude,
                                            longitude: mark.coordinate.longitude
                                        )
                                        context.insert(spot)
                                        navigation.goToSpot(spot: spot)
                                    }
                                }
                                stateManager.showingAlertForSpotBookmark.toggle()
                            }) {
                                Image(systemName: "bookmark.circle.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .alert("Spot bookmarked", isPresented: $stateManager.showingAlertForSpotBookmark) {
                                Button("OK", role: .cancel) {
                                    stateManager.marks = []
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Text("Clear Mark")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                stateManager.marks = []
                            }) {
                                Image(systemName: "clear.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.trailing, 20)
                    
                    Spacer()
                }
            }
        }
        .animation(.easeInOut, value: isInviteCopied)
    }

    func debugOutput() -> String {
        if let error = apiService.error {
            return error.localizedDescription
        }
        return apiService.isLoading ? "Loading..." : "🚹 \(network.connected ? "🟢 " : "")Welcome to SkateConnect, 🇺🇸!"
    }
}
