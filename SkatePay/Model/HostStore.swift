//
//  HostStore.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import SwiftUI

@MainActor
class HostStore: ObservableObject {
    @Published var host: Host = Host()
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("host.data")
    }
    
    func load() async throws {
        let task = Task<Host, Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return Host()
            }
            
            let host = try JSONDecoder().decode(Host.self, from: data)
            return host
        }
        
        let host = try await task.value
        self.host = host
    }
    
    func save(host: Host) async throws {
        let task = Task {
            let data = try JSONEncoder().encode(host)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
    }
}
