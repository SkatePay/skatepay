//
//  TokenPrice.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/5/24.
//

import Foundation

// A structure for handling token price
public struct TokenPrice: Hashable, Codable {
    /// ISO 4217 Currency code
    public let currencyCode: String

    /// Token that keep the price
    public let token: SomeToken

    /// Value of price
    public let value: UInt64

    @available(*, deprecated, message: "Never use double for store fiat.")
    public var doubleValue: Double {
        Double(value.description) ?? 0.0
    }
}
