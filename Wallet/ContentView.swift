//
//  ContentView.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            MapView()
                .frame(height: 300)
            
            CircleImage()
                .offset(y: -130)
                .padding(.bottom, -130)
            
            VStack(alignment: .leading) {
                Text("Venice Skate Park").font(.title).foregroundColor(.orange)
                HStack {
                    Text("1800 Ocean Front Walk")
                    Spacer()
                    Text("Venice, CA 90291")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                Divider()
                
                Text("Park Description")
                    .font(.title2)
                Text("Great skatepark of the beach.")
            }
            .padding()
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
