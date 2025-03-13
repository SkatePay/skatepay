//
//  UploadManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/7/24.
//

import os

import Combine
import ConnectFramework
import Foundation

class UploadManager: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "UploadManager")

    @Published var isUploading = false
    @Published private var navigation: Navigation?
    @Published var videoURL: URL?

    let keychainForAws = AwsKeychainStorage()
    
    private var cancellables = Set<AnyCancellable>()
        
    func setNavigation(navigation: Navigation) {
        self.navigation = navigation
    }
    
    init () {
        NotificationCenter.default.publisher(for: .didFinishRecordingTo)
            .sink { [weak self] notification in
                guard let videoURL = notification.userInfo?["videoURL"] as? URL, let log = self?.log else { return }
                self?.videoURL = videoURL
                os_log("✔️ received: %@", log: log, type: .info, videoURL.absoluteString)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Upload Files
    func uploadFiles(imageURL: URL) async throws {
        os_log("⏳ uploading files", log: log, type: .info)

        guard let channelId = navigation?.channelId else {
            os_log("🛑 Error: Channel ID is nil.", log: log, type: .error)
            return
        }
        
        do {
            try await uploadImage(imageURL: imageURL, channelId: channelId)
            
            guard let videoURL = videoURL  else {
                os_log("🛑 Error: videoURL is nil.", log: log, type: .error)
                return
            }
            
            try await uploadVideo(videoURL: videoURL, channelId: channelId)

        } catch {
            os_log("🔥 Upload failed: %@", log: self.log, type: .error, error.localizedDescription)
            throw error
        }

        NotificationCenter.default.post(
            name: .didFinishUpload,
            object: nil
        )
    }
    
    // Upload image to S3
    func uploadImage(imageURL: URL, channelId: String = "") async throws {
        os_log("⏳ uploading image [%@] [%@]", log: log, type: .info, imageURL.absoluteString, channelId)

        guard let keys = keychainForAws.keys else {
            os_log("🛑 can't get aws keychain", log: log, type: .info)
            return
        }

        isUploading = true
        
        do {
            let serviceHandler = try await S3ServiceHandler(
                region: "us-west-2",
                accessKeyId: keys.S3_ACCESS_KEY_ID,
                secretAccessKey: keys.S3_SECRET_ACCESS_KEY
            )
            
            let objName = imageURL.lastPathComponent
            try await serviceHandler.uploadFile(
                bucket: Constants.S3_BUCKET,
                key: objName,
                fileUrl: imageURL,
                tagging: channelId.isEmpty ? "" : "channel=\(channelId)"
            )
            
            isUploading = false
            os_log("✔️ image uploaded to S3: %@", log: log, type: .info, objName)
        } catch {
            os_log("🔥 upload failed: %@", log: self.log, type: .info, error.localizedDescription)
            isUploading = false

            throw error
        }
    }
    
    // Upload video to S3
    func uploadVideo(videoURL: URL, channelId: String = "") async throws {
        os_log("⏳ uploading video [%@] [%@]", log: log, type: .info, videoURL.absoluteString, channelId)
        
        guard let keys = keychainForAws.keys else {
            os_log("🛑 can't get aws keychain", log: log, type: .info)
            return
        }
        
        isUploading = true

        do {
            let serviceHandler = try await S3ServiceHandler(
                region: "us-west-2",
                accessKeyId: keys.S3_ACCESS_KEY_ID,
                secretAccessKey: keys.S3_SECRET_ACCESS_KEY
            )
            
            let objName = videoURL.lastPathComponent
            try await serviceHandler.uploadFile(
                bucket: Constants.S3_BUCKET,
                key: objName,
                fileUrl: videoURL,
                tagging: channelId.isEmpty ? "" : "channel=\(channelId)"
            )
            isUploading = false
            os_log("✔️ video uploaded to S3: %@", log: log, type: .info, objName)

        } catch {
            os_log("🔥 upload failed: %@", log: self.log, type: .info, error.localizedDescription)
            isUploading = false

            throw error
        }
    }
    
    // Optional function to request a temporary token
    func requestTemporaryToken(bucket: String) async throws -> String? {        
        let url = URL(string: "\(Constants.API_URL_SKATEPARK)/token?bucket=\(bucket)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        return (json as! [String: String])["token"]!
    }
}
