//
//  SearchView.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/13/24.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var navigation: NavigationManager

    @State private var coordinates: String = ""
    @State private var channelId: String = ""
    
    @State private var showingAlert = false

    var body: some View {
        Form {
            Section("coordinates") {
                TextField("{ \"latitude\": 0.0, \"longitude\": 0.0 }", text: $coordinates)
            }
            Section("channel") {
                TextField("channel", text: $channelId)
            }
            Button("Search") {
                showingAlert.toggle()
            }
            .alert("Start search.", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .disabled(!readyToSend())
        }
    }
    
    private func readyToSend() -> Bool {
        (!coordinates.isEmpty || !channelId.isEmpty)
    }
}

#Preview {
    SearchView(navigation: NavigationManager())
}
