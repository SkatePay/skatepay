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
            UserDefaults.standard.set(hasEnabledDebug, forKey: UserDefaults.Keys.hasEnabledDebug)
        }
    }

    init() {
        self.hasEnabledDebug = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hasEnabledDebug)
    }

    func enableDebug() {
        hasEnabledDebug = true
    }
    
    func resetDebug() {
        hasEnabledDebug = false
    }
}

