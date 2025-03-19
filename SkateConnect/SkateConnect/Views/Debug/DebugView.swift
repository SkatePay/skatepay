//
//  DebugView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/17/25.
//

import SwiftUI

struct DebugView<Content: View>: View {
    let content: Content
    let id = UUID()
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        print("Creating DebugView with ID: \(id)")
    }
    
    var body: some View {
        content.onAppear {
            print("DebugView with ID: \(id) appeared")
        }
    }
}
