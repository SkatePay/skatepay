//
//  UploadManager.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/7/24.
//

import ConnectFramework
import Foundation

class UploadManager {
    let keychainForAws: AwsKeychainStorage
    
    init(keychainForAws: AwsKeychainStorage) {
        self.keychainForAws = keychainForAws
    }
    
    // Upload image to S3
    func uploadImage(imageURL: URL, channelId: String = "") async throws {
        let serviceHandler = try await S3ServiceHandler(
            region: "us-west-2",
            accessKeyId: keychainForAws.keys?.S3_ACCESS_KEY_ID,
            secretAccessKey: keychainForAws.keys?.S3_SECRET_ACCESS_KEY
        )
        
        let objName = imageURL.lastPathComponent
        try await serviceHandler.uploadFile(
            bucket: Constants.S3_BUCKET,
            key: objName,
            fileUrl: imageURL,
            tagging: channelId.isEmpty ? "" : "channel=\(channelId)"
        )
        print("Image uploaded to S3: \(objName)")
    }
    
    // Upload video to S3
    func uploadVideo(videoURL: URL, channelId: String = "") async throws {
        let serviceHandler = try await S3ServiceHandler(
            region: "us-west-2",
            accessKeyId: keychainForAws.keys?.S3_ACCESS_KEY_ID,
            secretAccessKey: keychainForAws.keys?.S3_SECRET_ACCESS_KEY
        )
        
        let objName = videoURL.lastPathComponent
        try await serviceHandler.uploadFile(
            bucket: Constants.S3_BUCKET,
            key: objName,
            fileUrl: videoURL,
            tagging: channelId.isEmpty ? "" : "channel=\(channelId)"
        )
        print("Video uploaded to S3: \(objName)")
    }
    
    // Optional function to request a temporary token
    func requestTemporaryToken(bucket: String) async throws -> String {
        let url = URL(string: "\(Constants.API_URL_SKATEPARK)/token?bucket=\(bucket)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return (json as! [String: String])["token"]!
    }
}
