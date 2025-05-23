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

enum Tab {
    case lobby
    case map
    case wallet
    case settings
}

enum NavigationPathType: Hashable {
    case addressBook
    case barcodeScanner
    case birthday
    case camera
    case channel(channelId: String, invite: Bool = false)
    case connectRelay
    case contacts
    case createChannel
    case createMessage
    case deckDetails(image: UIImage, fileURL: URL)
    case deckTracker
    case directMessage(user: User)
    case filters
    case importIdentity
    case importWallet
    case landmarkDirectory
    case recoveryPhrase(mnemonic: [String])
    case reportUser(user: User, message: String)
    case restoreData
    case search
    case transferAsset(transferType: TransferType)
    case userDetail(npub: String)
    case videoPlayer(url: URL)
}

enum ActiveView {
    case map
    case lobby
    case settings
    case other
}

class Navigation: ObservableObject {
    @Published var path = NavigationPath()

    @Published var tab: Tab = .map
    
    @Published var activeView: ActiveView = .other
    
    @Published var channelId: String?
    @Published var user: User?
    
    @Published var landmark: Landmark?
    @Published var coordinate: CLLocationCoordinate2D?
                                
    @Published var isShowingEditChannel = false
        
    let keychainForNostr = NostrKeychainStorage()

    func isMe(npub: String) -> Bool {
        return keychainForNostr.account?.publicKey.npub == npub
    }
    
    func isMe(pubkey: String) -> Bool {
        return keychainForNostr.account?.publicKey.hex == pubkey
    }
    
    var isLocationUpdatePaused: Bool {
        return isShowingEditChannel
    }
    
    func recoverFromSearch() {
        NotificationCenter.default.post(name: .goToCoordinate, object: nil)
    }
    
    func joinChannel(channelId: String) {
        NotificationCenter.default.post(
            name: .subscribeToChannel,
            object: self,
            userInfo: ["channelId": channelId]
        )
    }
    
    func goToCoordinate() {
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
            userInfo: ["channelId": channelId, "assetURL": assetURL]
        )
        
        self.channelId = nil
    }
    
    func completeUpload(imageURL: URL, userInfo: [String: Any] = [:]) {
        var userInfo = userInfo
        let filename = imageURL.lastPathComponent
        let assetURL = "https://\(Constants.S3_BUCKET).s3.us-west-2.amazonaws.com/\(filename)"

        userInfo["assetURL"] = assetURL

        NotificationCenter.default.post(
            name: UploadNotification.Image,
            object: self,
            userInfo: userInfo
        )
    }
}
