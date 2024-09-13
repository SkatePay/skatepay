//
//  ChatError.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/1/24.
//

import Foundation

enum ChatError: Error {
    case unknown(source: Error?)
}
