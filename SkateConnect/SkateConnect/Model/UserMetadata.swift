//
//  UserMetadata.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/12/25.
//

import Foundation

struct UserMetadata: Codable {
    let name: String?
    let picture: String?

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Error encoding Note to JSON string: \(error)")
            return nil
        }
    }

    static func fromJSONString(_ jsonString: String) -> UserMetadata? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(UserMetadata.self, from: data)
        } catch {
            print("Error decoding Note from JSON string: \(error)")
            return nil
        }
    }
}
