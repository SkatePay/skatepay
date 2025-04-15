//
//  AppVersionChecker.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/14/25.
//

import Foundation
import UIKit

public struct AppVersionChecker {
    public enum VersionError: Error, CustomStringConvertible {
        case invalidBundleIdentifier
        case invalidAppStoreURL
        case networkError(Error)
        case invalidResponse
        case versionComparisonFailed
        
        public var description: String {
            switch self {
            case .invalidBundleIdentifier: "Could not get app bundle identifier"
            case .invalidAppStoreURL: "Could not create App Store URL"
            case .networkError(let error): "Network error: \(error.localizedDescription)"
            case .invalidResponse: "Invalid response from App Store"
            case .versionComparisonFailed: "Could not compare versions"
            }
        }
    }
    
    /// Gets the current app version from the bundle
    public static var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    /// Checks if an update is available
    /// - Returns: Tuple with (needsUpdate: Bool, appStoreVersion: String, appStoreURL: URL)
    public static func checkForUpdate() async throws -> (needsUpdate: Bool, appStoreVersion: String, appStoreURL: URL) {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            throw VersionError.invalidBundleIdentifier
        }
        
        let lookupURLString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        guard let lookupURL = URL(string: lookupURLString) else {
            throw VersionError.invalidAppStoreURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let result = try JSONDecoder().decode(AppStoreLookupResult.self, from: data)
        
        guard let appInfo = result.results.first,
              let appStoreVersion = appInfo.version,
              let appStoreURLString = appInfo.trackViewUrl,
              let appStoreURL = URL(string: appStoreURLString) else {
            throw VersionError.invalidResponse
        }
        
        guard let currentVersion = currentVersion else {
            throw VersionError.versionComparisonFailed
        }
        
        let needsUpdate = currentVersion.compare(appStoreVersion, options: .numeric) == .orderedAscending
        return (needsUpdate, appStoreVersion, appStoreURL)
    }
    
    /// Opens the App Store page for the app
    /// - Parameter url: The App Store URL to open
    /// - Returns: true if the URL was opened successfully, false otherwise
    @MainActor
    public static func openAppStore(url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            return false
        }
        return await UIApplication.shared.open(url)
    }
}

private struct AppStoreLookupResult: Codable {
    let results: [AppStoreAppInfo]
}

private struct AppStoreAppInfo: Codable {
    let version: String?
    let trackViewUrl: String?
}
