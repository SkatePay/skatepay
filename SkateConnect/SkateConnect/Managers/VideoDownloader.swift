//
//  VideoDownloader.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/26/25.
//

import Foundation
import Photos
import OSLog

class VideoDownloader: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "VideoDownloader")

    func downloadVideo(from url: URL, onLoadingStateChange: @escaping (Bool, Error?) -> Void) {
        logger.info("Attempting to download video from \(url)")

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 120

        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        onLoadingStateChange(true, nil)
        
        let downloadTask = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else {
                Logger(subsystem: Bundle.main.bundleIdentifier!, category: "VideoDownloader")
                    .warning("VideoDownloader instance was nil in completion handler")
                if let tempURL = tempURL { try? FileManager.default.removeItem(at: tempURL) }
                return
            }

            self.logger.debug("Download task completion handler reached")

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    self.logger.error("❌ Download failed: Timeout - \(error.localizedDescription)")
                } else {
                    self.logger.error("❌ Download failed: \(error.localizedDescription)")
                }
                
                onLoadingStateChange(false, error)
                return
            }

            guard let tempURL = tempURL else {
                self.logger.error("⚠️ No temporary file URL received")
                onLoadingStateChange(true, nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("⚠️ Invalid server response")
                try? FileManager.default.removeItem(at: tempURL)
                onLoadingStateChange(true, nil)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                self.logger.error("⚠️ Server error: HTTP \(httpResponse.statusCode)")
                try? FileManager.default.removeItem(at: tempURL)
                onLoadingStateChange(true, nil)
                return
            }

            self.logger.info("✅ Download successful")
            
            onLoadingStateChange(false, nil)
            
            self.saveVideoToCameraRoll(tempVideoURL: tempURL, originalURL: url)
        }

        downloadTask.resume()
        logger.info("Download task started (ID: \(downloadTask.taskIdentifier))")
    }

    func saveVideoToCameraRoll(tempVideoURL: URL, originalURL: URL) {
        logger.info("Requesting save for temp file")
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            performSave(tempVideoURL: tempVideoURL, originalURL: originalURL)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.performSave(tempVideoURL: tempVideoURL, originalURL: originalURL)
                    } else {
                        self?.logger.warning("Permission denied")
                        try? FileManager.default.removeItem(at: tempVideoURL)
                    }
                }
            }
        case .denied, .restricted:
            logger.warning("Photo Library access denied")
            try? FileManager.default.removeItem(at: tempVideoURL)
        @unknown default:
            logger.error("Unknown authorization status")
            try? FileManager.default.removeItem(at: tempVideoURL)
        }
    }

    private func renameTempFileToVideo(_ tempURL: URL, originalURL: URL) -> URL? {
        let fileManager = FileManager.default
        let originalExtension = originalURL.pathExtension.lowercased()
        let supportedFormats = ["mov", "mp4", "m4v"]

        guard supportedFormats.contains(originalExtension) else {
            logger.error("Unsupported video format")
            return nil
        }

        let newURL = tempURL.deletingPathExtension().appendingPathExtension(originalExtension)

        do {
            if fileManager.fileExists(atPath: newURL.path) {
                try fileManager.removeItem(at: newURL)
            }
            try fileManager.moveItem(at: tempURL, to: newURL)
            return newURL
        } catch {
            logger.error("Failed to rename file")
            return nil
        }
    }

    private func performSave(tempVideoURL: URL, originalURL: URL) {
        logger.info("Attempting performSave")
        guard let renamedURL = renameTempFileToVideo(tempVideoURL, originalURL: originalURL) else {
            logger.error("Failed to rename file")
            try? FileManager.default.removeItem(at: tempVideoURL)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: renamedURL)
        }) { success, error in
            DispatchQueue.main.async {
                do {
                    try FileManager.default.removeItem(at: renamedURL)
                } catch {
                    self.logger.warning("Could not remove renamed file")
                }

                if success {
                    self.logger.info("✅ Successfully saved video")
                } else if let error = error {
                    self.logger.error("❌ Error saving video")
                } else {
                    self.logger.error("❌ Unknown error")
                }
            }
        }
    }

    deinit {
        Logger(subsystem: Bundle.main.bundleIdentifier!, category: "VideoDownloader")
            .critical("‼️ VideoDownloader deallocated")
    }
}
