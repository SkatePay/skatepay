//
//  Note.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/1/25.
//

import Foundation

struct Note: Codable {
    let kind: String
    let text: String

    init(kind: String, text: String) {
        self.kind = kind
        self.text = text
    }

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

    static func fromJSONString(_ jsonString: String) -> Note? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Note.self, from: data)
        } catch {
            print("Error decoding Note from JSON string: \(error)")
            return nil
        }
    }
}
