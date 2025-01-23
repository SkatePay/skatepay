//
//  DemoHelper.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/31/24.
//

import ConnectFramework
import SwiftUI
import NostrSDK

struct DemoHelper {
    static var emptyString: Binding<String> {
        Binding.constant("")
    }
    static var previewRelay: Binding<Relay?> {
        let urlString = Constants.RELAY_URL_SKATEPARK

        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL: \(urlString)")
        }
        // If the Relay initializer throws an error, replace 'try?' with your error handling.
        let relay = try? Relay(url: url)

        return Binding.constant(relay)
    }
    static var validNpub: Binding<String> {
        Binding.constant("npub1mnjxzzjyx786qpy6yptwj3rheenedcuvynau7zv532rekdfyzyxsampx25")
    }
    /// This project and its maintainers take no responsibility of events signed with this private key which has been open sourced.
    /// Its purpose is for only testing and demos.
    static var validNsec: Binding<String> {
        Binding.constant("nsec128d8hfx9vmk8y88frwcs49yf0umzx78n9yfwj5jrry24uc66n8uszelw26")
    }
    static var validHexPublicKey: Binding<String> {
        Binding.constant("dce4610a44378fa0049a2056e94477ce6796e38c24fbcf09948a879b3524110d")
    }
    /// This project and its maintainers take no responsibility of events signed with this private key which has been open sourced.
    /// Its purpose is for only testing and demos.
    static var validHexPrivateKey: Binding<String> {
        Binding.constant("51da7ba4c566ec721ce91bb10a94897f362378f32912e9524319155e635a99f9")
    }
    static var invalidKey: Binding<String> {
        Binding.constant("not-valid")
    }
}
