//
//  Navigation.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import ConnectFramework
import CoreLocation
import Foundation
import SwiftUI

extension Notification.Name {
    static let goToLandmark = Notification.Name("goToLandmark")
    static let goToCoordinate = Notification.Name("goToCoordinate")
    static let goToSpot = Notification.Name("goToSpot")
    static let joinChat = Notification.Name("joinChat")
    static let muteUser = Notification.Name("muteUser")
    static let barcodeScanned = Notification.Name("barcodeScanned")
    static let uploadVideo = Notification.Name("uploadVideo")
}

class Navigation: ObservableObject {
    static let shared = Navigation()
    
    @Published var path = NavigationPath()
    @Published var tab: Tab = .map
    
    @Published var landmark: Landmark?
    @Published var coordinate: CLLocationCoordinate2D?
    
    @Published var isShowingEULA = false
    @Published var isShowingDirectory = false
    @Published var isShowingChannelView = false
    @Published var isShowingSearch = false
    @Published var isShowingMarkerOptions = false
    
    @Published var isShowingUserDetail = false
    
    @Published var isShowingBarcodeScanner = false
    
    @Published var isShowingCameraView = false
    
    @Published var isShowingAddressBook = false
    @Published var isShowingContacts = false
    @Published var isShowingCreateMessage = false
    
    @Published var isShowingCreateChannel = false
    @Published var isShowingChatView = false
    @Published var isShowingEditChannel = false
    
    @Published var isShowingVideoPlayer = false
    
    var isLocationUpdatePaused: Bool {
        return isShowingChannelView || isShowingSearch || isShowingMarkerOptions ||
               isShowingUserDetail || isShowingBarcodeScanner || isShowingCameraView ||
               isShowingAddressBook || isShowingContacts || isShowingCreateMessage ||
               isShowingCreateChannel || isShowingChatView || isShowingEditChannel ||
               isShowingEULA || isShowingDirectory || isShowingVideoPlayer
    }
    
    @Published var hasAcknowledgedEULA: Bool = UserDefaults.standard.bool(forKey: "hasAcknowledgedEULA")

    func acknowledgeEULA() {
        hasAcknowledgedEULA = true
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedEULA")
    }
    
    func dismissToContentView() {
        path = NavigationPath()
        NotificationCenter.default.post(name: .goToLandmark, object: nil)
        isShowingDirectory = false
    }
    
    func dismissToSkateView() {
        isShowingMarkerOptions = false
        isShowingCreateChannel = false
    }
    
    func recoverFromSearch() {
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
        isShowingSearch = false
    }
    
    func joinChat(channelId: String) {
        NotificationCenter.default.post(
            name: .joinChat,
            object: self,
            userInfo: ["channelId": channelId]
        )
        isShowingSearch = false
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
        
        NotificationCenter.default.post(
            name: .uploadVideo,
            object: self,
            userInfo: ["assetURL": assetURL]
        )
    }
}
