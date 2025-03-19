//
//  ChannelHelper.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/18/25.
//

import UIKit

class ChannelHelper {
    static func decodeAbout(_ about: String?) -> AboutStructure? {
        guard let about = about else { return nil }
        do {
            let decoder = JSONDecoder()
            let decodedStructure = try decoder.decode(AboutStructure.self, from: about.data(using: .utf8)!)
            return decodedStructure
        } catch {
            return nil
        }
    }
}
