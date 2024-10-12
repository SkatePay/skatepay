//
//  Color+Extension.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import SwiftUI

extension Color {
    static var exampleGrey = Color(hex: "1F1F1F")
}

extension Color {
    init?(hex: String) {
        let r, g, b: Double
        
        if hex.hasPrefix("#"), let hexNumber = Int(hex.dropFirst(), radix: 16) {
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double(hexNumber & 0x0000FF) / 255
            self.init(red: r, green: g, blue: b)
        } else {
            return nil
        }
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
        return String(format: "#%06x", rgb)
    }
}
