//
//  Notifications.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/26/25.
//

import Foundation

enum UploadNotification {
    case uploadImage(String, String?, String?) // imageIdentifier, channelId, npub
    case uploadVideo(String, String?, String?) // videoIdentifier, channelId, npub

    // --- Static constants for Notification Names ---
    static let Image = Notification.Name("uploadImage")
    static let Video = Notification.Name("uploadVideo")
    // --- ---

    // Instance property to get the name (optional now, but can be useful)
    var name: Notification.Name {
        switch self {
        case .uploadImage:
            return UploadNotification.Image // Use the static constant
        case .uploadVideo:
            return UploadNotification.Video // Use the static constant
        }
    }

    // UserInfo generation remains the same
    var userInfo: [String: Any]? {
        switch self {
        case .uploadImage(let identifier, let channelId, let npub):
            var userInfo: [String: Any] = ["imageIdentifier": identifier] // Key is imageIdentifier
            if let channelId = channelId {
                userInfo["channelId"] = channelId
            }
            if let npub = npub {
                userInfo["npub"] = npub
            }
            return userInfo
        case .uploadVideo(let identifier, let channelId, let npub):
            var userInfo: [String: Any] = ["videoIdentifier": identifier] // Key is videoIdentifier
             if let channelId = channelId {
                 userInfo["channelId"] = channelId
             }
             if let npub = npub {
                 userInfo["npub"] = npub
             }
             return userInfo
        }
    }
}
