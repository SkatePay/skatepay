//
//  MarkControls.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI

struct MarkControls: View {
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var stateManager: StateManager
    
    var body: some View {
        if !stateManager.marks.isEmpty {
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    HStack {
                        Text("Mark Spot")
                            .font(.caption)
                            .foregroundColor(.white)
                        Button(action: {
                            navigation.path.append(NavigationPathType.createChannel)
                        }) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
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
        } else {
            EmptyView()
        }
    }
}
