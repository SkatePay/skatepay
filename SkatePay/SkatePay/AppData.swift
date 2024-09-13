//
//  AppData.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import Foundation
import ConnectFramework

@Observable
class AppData {
    var landmarks: [Landmark] = load("landmarkData.json")
    var users: [User] = load("userData.json")
    var profile = Profile.default
}
