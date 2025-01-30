//
//  DebugManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/27/25.
//

import Foundation

class DebugManager: ObservableObject {
    @Published var hasEnabledDebug: Bool {
        didSet {
            UserDefaults.standard.set(hasEnabledDebug, forKey: "hasEnabledDebug")
        }
    }

    init() {
        self.hasEnabledDebug = UserDefaults.standard.bool(forKey: "hasEnabledDebug")
    }

    func enableDebug() {
        hasEnabledDebug = true
    }
    
    func resetDebug() {
        hasEnabledDebug = false
    }
}

