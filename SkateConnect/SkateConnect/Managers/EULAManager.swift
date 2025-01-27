//
//  EULAManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/23/25.
//

import Foundation

class EULAManager: ObservableObject {
    @Published var hasAcknowledgedEULA: Bool {
        didSet {
            UserDefaults.standard.set(hasAcknowledgedEULA, forKey: "hasAcknowledgedEULA")
        }
    }

    init() {
        self.hasAcknowledgedEULA = UserDefaults.standard.bool(forKey: "hasAcknowledgedEULA")
    }

    func acknowledgeEULA() {
        hasAcknowledgedEULA = true
    }
    
    func resetEULA() {
        hasAcknowledgedEULA = false
    }
}
