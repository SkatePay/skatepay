//
//  Navigation.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import ConnectFramework
import CoreLocation
import Foundation
import NostrSDK
import SwiftUI

extension Notification.Name {
    static let goToLandmark = Notification.Name("goToLandmark")
    static let goToCoordinate = Notification.Name("goToCoordinate")
    static let goToSpot = Notification.Name("goToSpot")
    static let joinChannel = Notification.Name("joinChannel")
    static let muteUser = Notification.Name("muteUser")
    static let barcodeScanned = Notification.Name("barcodeScanned")
    static let uploadImage = Notification.Name("uploadImage")
    static let uploadVideo = Notification.Name("uploadVideo")
}

enum ActiveView {
    case map
    case lobby
    case settings
    case other
}

enum ActiveSheet {
    case addressBook
    case barcodeScanner
    case camera
    case channel
    case contacts
    case createMessage
    case createChannel
    case directMessage
    case directory
    case filters
    case none
    case videoPlayer
    case search
    case userDetail
}


class Navigation: ObservableObject {
    static let shared = Navigation()
    
    @Published var tab: Tab = .map
    
    @Published var activeView: ActiveView = .other
    @Published var activeSheet: ActiveSheet = .none
    
    @Published var path = NavigationPath()

    @Published var channelId: String?
    @Published var channel: NostrEvent?
    
    @Published var selectedUser: User?
    
    @Published var landmark: Landmark?
    @Published var coordinate: CLLocationCoordinate2D?
                            
    @Published var isShowingAddressBook = false
    @Published var isShowingContacts = false
    @Published var isShowingCreateMessage = false
    
    @Published var isShowingChatView = false
    @Published var isShowingEditChannel = false
    
    @Published var isShowingVideoPlayer = false
    
    // UserDetail
    @Published var isShowingUserDetail = false
    @Published var selectedUserNpub: String?
    
    var isLocationUpdatePaused: Bool {
        return isShowingUserDetail ||
               isShowingAddressBook || isShowingContacts || isShowingCreateMessage || isShowingChatView || isShowingEditChannel || isShowingVideoPlayer
    }
    
    func dismissToContentView() {
        path = NavigationPath()
        NotificationCenter.default.post(name: .goToLandmark, object: nil)
        activeSheet = .none
    }
    
    func recoverFromSearch() {
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
        activeSheet = .none
    }
    
    func joinChannel(channelId: String) {
        NotificationCenter.default.post(
            name: .joinChannel,
            object: self,
            userInfo: ["channelId": channelId]
        )
        activeSheet = .none
    }
    
    func goToSpot(spot: Spot) {
        isShowingAddressBook = false
        self.tab = .map
        
        NotificationCenter.default.post(
            name: .goToSpot,
            object: spot
        )
    }
    
    func goToCoordinate() {
        isShowingAddressBook = false
        self.tab = .map
        
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
    }
    
    func completeUpload(videoURL: URL) {
        let filename = videoURL.lastPathComponent
        let assetURL = "https://\(Constants.S3_BUCKET).s3.us-west-2.amazonaws.com/\(filename)"
        
        guard let channelId = channelId else { return }
        
        NotificationCenter.default.post(
            name: .uploadVideo,
            object: self,
            userInfo: ["channelId": channelId,
                       "assetURL": assetURL]
        )
    }
    
    func completeUpload(imageURL: URL) {
        let filename = imageURL.lastPathComponent
        let assetURL = "https://\(Constants.S3_BUCKET).s3.us-west-2.amazonaws.com/\(filename)"
        
        NotificationCenter.default.post(
            name: .uploadImage,
            object: self,
            userInfo: ["assetURL": assetURL]
        )
    }
}
