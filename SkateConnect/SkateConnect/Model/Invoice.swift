//
//  Invoice.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/16/2025
//

import UIKit
import NostrSDK

struct Invoice: Codable {
    var asset: AssetType
    var metadata: String?
    var amount: String
    var address: String
    var creationEvent: NostrEvent?
    
    static func encodeInvoiceToString(_ invoice: Invoice) -> String? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(invoice)
            return data.base64EncodedString()
        } catch {
            print("❌ Failed to encode invoice: \(error)")
            return nil
        }
    }
    
    static func decodeInvoiceFromString(_ encodedString: String) -> Invoice? {
        guard let data = Data(base64Encoded: encodedString) else {
            print("❌ Failed to base64 decode string")
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let invoice = try decoder.decode(Invoice.self, from: data)
            return invoice
        } catch {
            print("❌ Failed to decode invoice: \(error)")
            return nil
        }
    }
}
