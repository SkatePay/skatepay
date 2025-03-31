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
    
    func uploadFiles(imageURL: URL, onLoadingStateChange: @escaping (Bool, Error?) -> Void) async throws {
        os_log("⏳ uploading files", log: log, type: .info)

        let channelId = navigation?.channelId
        let npub = navigation?.user?.npub

        guard channelId != nil || npub != nil else {
            os_log("🛑 Error: Neither Channel ID nor npub is available from navigation. Cannot determine S3 tag.", log: log, type: .error)
            await MainActor.run { onLoadingStateChange(false, UploadError.missingTaggingInfo) }
            return
        }

        guard let videoURL = self.videoURL else {
            os_log("🛑 Error: videoURL is nil.", log: log, type: .error)
            await MainActor.run { onLoadingStateChange(false, UploadError.missingVideoURL) }
            return
        }

        do {
            try await uploadImage(
                imageURL: imageURL,
                channelId: channelId,
                npub: npub,
                onLoadingStateChange: onLoadingStateChange
            )

            try await uploadVideo(
                videoURL: videoURL,
                channelId: channelId,
                npub: npub,
                onLoadingStateChange: onLoadingStateChange
            )

            NotificationCenter.default.post(
                name: .didFinishUpload,
                object: nil
            )
            os_log("✔️ Both image and video uploads finished successfully.", log: log, type: .info)

        } catch {
            os_log("🔥 Upload sequence failed: %@", log: self.log, type: .error, error.localizedDescription)
            throw error
        }
    }


    func uploadImage(imageURL: URL, channelId: String?, npub: String?, onLoadingStateChange: @escaping (Bool, Error?) -> Void) async throws {
        guard let keys = keychainForAws.keys else {
            os_log("🛑 can't get aws keychain", log: log, type: .info)
            return
        }

        var tags: [String] = []
        if let channelId = channelId {
            os_log("⏳ uploading image [%@] for channelId=[%@]", log: log, type: .info, imageURL.absoluteString, channelId)
            tags.append("channel=\(channelId)")
        }
        if let npub = npub {
            os_log("⏳ uploading image [%@] for npub=[%@]", log: log, type: .info, imageURL.absoluteString, npub)
            tags.append("user=\(npub)")
        }

        let tagging = tags.joined(separator: "&")

        guard !tagging.isEmpty else {
             os_log("🛑 Error: No channelId or npub provided for tagging.", log: log, type: .error)
             await MainActor.run { onLoadingStateChange(false, UploadError.missingTaggingInfo) }
             return
        }

        await MainActor.run {
            onLoadingStateChange(true, nil)
        }

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
                tagging: tagging
            )

            await MainActor.run {
                onLoadingStateChange(false, nil)
            }

            os_log("✔️ image uploaded to S3: %@", log: log, type: .info, objName)
        } catch {
            os_log("🔥 upload failed: %@", log: self.log, type: .info, error.localizedDescription)

            await MainActor.run {
                onLoadingStateChange(false, error)
            }

            throw error
        }
    }


    func uploadVideo(videoURL: URL, channelId: String?, npub: String?, onLoadingStateChange: @escaping (Bool, Error?) -> Void) async throws {
        guard let keys = keychainForAws.keys else {
            os_log("🛑 can't get aws keychain", log: log, type: .info)
            return
        }

        var tags: [String] = []
        if let channelId = channelId {
            os_log("⏳ uploading video [%@] for channelId=[%@]", log: log, type: .info, videoURL.absoluteString, channelId)
            tags.append("channel=\(channelId)")
        }
        if let npub = npub {
            os_log("⏳ uploading video [%@] for npub=[%@]", log: log, type: .info, videoURL.absoluteString, npub)
            tags.append("user=\(npub)")
        }
        let tagging = tags.joined(separator: "&")

        guard !tagging.isEmpty else {
            os_log("🛑 Error: No channelId or npub provided for tagging.", log: log, type: .error)
            await MainActor.run { onLoadingStateChange(false, UploadError.missingTaggingInfo) }
            return
       }

        await MainActor.run {
            onLoadingStateChange(true, nil)
        }

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
                tagging: tagging
            )

            await MainActor.run {
                onLoadingStateChange(false, nil)
            }

            os_log("✔️ video uploaded to S3: %@", log: log, type: .info, objName)

        } catch {
            os_log("🔥 upload failed: %@", log: self.log, type: .info, error.localizedDescription)

            await MainActor.run {
                onLoadingStateChange(false, error)
            }

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


enum UploadError: Error { case missingTaggingInfo, missingVideoURL }
