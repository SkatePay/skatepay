//
//  GlobalListener.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/11/24.
//

import Combine
import ConnectFramework
import Foundation
import UIKit

func shareVideo(_ videoUrl: URL) {
    // Implementation for sharing the video
    print("Sharing video URL: \(videoUrl)")

    if let url = URL(string: videoUrl.absoluteString) {
        let fileNameWithoutExtension = url.deletingPathExtension().lastPathComponent
        print("File name without extension: \(fileNameWithoutExtension)")
        
        // Construct the custom URL
        let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/video/\(fileNameWithoutExtension)"
        
        // Ensure it's a valid URL
        if let customUrl = URL(string: customUrlString) {
            print("Custom URL: \(customUrl)")
            
            // Open the custom URL
            if UIApplication.shared.canOpenURL(customUrl) {
                UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
            } else {
                print("Unable to open URL: \(customUrl)")
            }
        } else {
            print("Invalid custom URL")
        }
    }
}

func shareChannel(_ channelId: String) {
    // Implementation for sharing channel
    print("Sharing channel with id: \(channelId)")
    
    // Construct the custom URL
    let customUrlString = "\(Constants.LANDING_PAGE_SKATEPARK)/channel/\(channelId)"
    
    // Ensure it's a valid URL
    if let customUrl = URL(string: customUrlString) {
        print("Custom URL: \(customUrl)")
        
        // Open the custom URL
        if UIApplication.shared.canOpenURL(customUrl) {
            UIApplication.shared.open(customUrl, options: [:], completionHandler: nil)
        } else {
            print("Unable to open URL: \(customUrl)")
        }
    } else {
        print("Invalid custom URL")
    }
}

class GlobalListener {
    static let shared = GlobalListener()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Start listening to notifications when initialized
        startListening()
    }
    
    private func startListening() {
        // Listen for uploadVideo notifications globally
        NotificationCenter.default.publisher(for: .uploadVideo)
            .sink { notification in
                if let assetURL = notification.userInfo?["assetURL"] as? String, let channelId = notification.userInfo?["channelId"] as? String  {
                    self.handleUploadVideo(channelId: channelId, assetURL: assetURL)
                }
            }
            .store(in: &cancellables)
        
        // Add more listeners here if needed
    }
    
    private func handleUploadVideo(channelId: String, assetURL: String) {
        let network = Network.shared
        network.publishVideoEvent(channelId: channelId, kind: .video, content: assetURL)
        print("Video uploaded: \(assetURL)")
    }
    
    // Add more handler methods for different notification types
}
