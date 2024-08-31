//
//  LobbyHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI

struct LobbyHome: View {
    @Environment(ModelData.self) var modelData
    
    var body: some View {
        NavigationSplitView {
            List {
                UserRow(users: modelData.users)
            }        
            .navigationTitle("Lobby")
        } detail: {
            Text("Select a Landmark")
        }
    }
}

#Preview {
    LobbyHome().environment(ModelData())
}
