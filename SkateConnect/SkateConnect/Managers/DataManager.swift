//
//  DataManager.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import os

import Combine
import ConnectFramework
import Foundation
import NostrSDK
import SwiftUI
import SwiftData
import SolanaSwift

@Observable
class AppData {
    var landmarks: [Landmark] = load("landmarkData.json")
    var users: [User] = load("userData.json")
    var profile = Profile.default
    
    func getSupport() -> User {
        return AppData().users[0]
    }
}

@MainActor
class DataManager: ObservableObject {
    let log = OSLog(subsystem: "SkateConnect", category: "DataManager")

    @Published private var lobby: Lobby?
    @Published private var walletManager: WalletManager?
    
    private let modelContainer: ModelContainer
    
    let keychainForNostr = NostrKeychainStorage()

    init(inMemory: Bool = false) {
        do {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: inMemory
            )
            self.modelContainer = try ModelContainer(
                for: Friend.self, Foe.self, Spot.self,
                configurations: config
            )        } catch {
            print("Failed to initialize ModelContainer: \(error)")
            fatalError("Failed to initialize ModelContainer")
        }
    }
    
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    func setLobby(lobby: Lobby) {
        self.lobby = lobby
    }
    
    func setWalletManager(walletManager: WalletManager) {
        self.walletManager = walletManager
    }
    
    func insertSpot(_ spot: Spot) {
        modelContext.insert(spot)
        do {
            try modelContext.save()
            
            let spots = fetchSortedSpots()
            
            lobby?.setupLeads(spots: spots)
        } catch {
            print("Failed saving: \(error)")
        }
    }
    
    func fetchSortedSpots() -> [Spot] {
        do {
            let fetchDescriptor = FetchDescriptor<Spot>(
                sortBy: [SortDescriptor(\.name, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Spots: \(error)")
            return []
        }
    }
    
    // MARK: Spots
    func findSpotForChannelId(_ channelId: String) -> Spot? {
        return fetchSortedSpots().first { $0.channelId == channelId }
    }
    
    func saveSpotForLead(_ lead: Lead, note: String = "") {
        var bufferedLead = lead
        
        if let spot = findSpotForChannelId(lead.channelId) {
            print("Spot already exists for eventId: \(spot.channelId) \(spot.note)")
            
            let note = spot.note.split(separator: ":").last.map(String.init) ?? ""
            bufferedLead.color = convertNoteToColor(note)
        } else {
            let spot = Spot(
                name: lead.name,
                address: "",
                state: "",
                icon: lead.icon,
                note: lead.icon + ":" + note,
                latitude: lead.coordinate.latitude,
                longitude: lead.coordinate.longitude,
                channelId: lead.channelId
            )
            
            self.insertSpot(spot)
            bufferedLead.color = convertNoteToColor(note)
            print("New spot inserted for eventId: \(lead.channelId)")
        }
        
        self.lobby?.upsertIntoLeads(bufferedLead)
    }
    
    func removeSpotForChannelId(_ channelId: String) {
        do {
            if let spotToRemove = findSpotForChannelId(channelId) {
                modelContext.delete(spotToRemove)
                try modelContext.save()

                // Re-fetch sorted spots and update the lobby leads
                let spots = fetchSortedSpots()
                            
                self.lobby?.setupLeads(spots: spots)
                self.lobby?.removeLeadByChannelId(channelId)
                
                print("Spot with channelId \(channelId) removed.")
            } else {
                print("Spot with channelId \(channelId) not found.")
            }
        } catch {
            print("Failed to remove spot: \(error)")
        }
    }
    
    func createPublicSpots(leads: [Lead]) {
        for lead in leads {
            saveSpotForLead(lead, note: "public")
        }
    }
    
    // MARK: Friends
    func fetchFriends() -> [Friend] {
        do {
            let fetchDescriptor = FetchDescriptor<Friend>(
                sortBy: [SortDescriptor(\.name, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Friends: \(error)")
            return []
        }
    }
    
    func findFriend(_ npub: String) -> Friend? {
        return fetchFriends().first(where: { $0.npub == npub })
    }
    
    func insertDefaultFriend() async {
        modelContext.insert(
            Friend(
                name: AppData().users[0].name,
                birthday: Date.now,
                npub: AppData().getSupport().npub,
                note: "Dispatch"
            )
        )
    }
    
    // MARK: Foes
    func fetchFoes() -> [Foe] {
        do {
            let fetchDescriptor = FetchDescriptor<Foe>(
                sortBy: [SortDescriptor(\.npub, order: .reverse)]
            )
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch and sort Foes: \(error)")
            return []
        }
    }
    
    func findFoes(_ npub: String) -> Foe? {
        return fetchFoes().first(where: { $0.npub == npub })
    }
    
    func getBlacklist() -> [String] {
        return self.fetchFoes().map { $0.npub }
    }
}

enum LeadType: String {
    case outbound = "outbound"
    case inbound = "inbound"
}

struct ContentStructure: Codable {
    let content: String
    let kind: Kind
}

enum Kind: String, Codable {
    case video
    case photo
    case message
    case hidden
    case subscriber
}


struct BackupData: Codable {
    let version: String?
    let build: String?
    var type: String? = nil
    let spots: [CodableSpot]?
    let friends: [CodableFriend]?
    let foes: [CodableFoe]?
    let solanaKeyPairs: [SolanaKeychainStorage.WalletData]?
    let nostrKeyPairs: NostrKeypair?
    let bots: [CodableBot]?
}

extension DataManager {
    func backupData() -> String? {
        // ✅ Fetch current app version and build dynamically
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        // Fetch all spots, friends, and foes
        let spots = fetchSortedSpots()
        let friends = fetchFriends()
        let foes = fetchFoes()
        
        // Convert SwiftData models to Codable versions
        let codableSpots = spots.map { CodableSpot(spot: $0) }
        let codableFriends = friends.map { CodableFriend(friend: $0) }
        let codableFoes = foes.map { CodableFoe(foe: $0) }
        
        // Fetch Solana key pairs
        let solanaStorage = SolanaKeychainStorage()
        let solanaAliases = solanaStorage.getAllAliases()
        var solanaKeyPairs: [SolanaKeychainStorage.WalletData] = []
        for alias in solanaAliases {
            if let keyPair = solanaStorage.get(alias: alias) {
                let walletData = SolanaKeychainStorage.WalletData(
                    alias: alias,
                    keyPair: keyPair.keyPair,
                    network: keyPair.network
                )
                solanaKeyPairs.append(walletData)
            }
        }
        
        // Fetch Nostr key pair
        let nostrKeyPair = keychainForNostr.account.map { NostrKeypair(privateKey: $0.privateKey.nsec, publicKey: $0.publicKey.npub) }
        
        let bots = loadBotsFromUserDefaults()
        
        // Create backup data using Codable versions
        let backupData = BackupData(
            version: appVersion,    // Store app version dynamically
            build: appBuild,        // Store app build dynamically
            spots: codableSpots,
            friends: codableFriends,
            foes: codableFoes,
            solanaKeyPairs: solanaKeyPairs,
            nostrKeyPairs: nostrKeyPair,
            bots: bots
        )
        
        // Encode to JSON
        do {
            let jsonData = try JSONEncoder().encode(backupData)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to encode backup data: \(error)")
            return nil
        }
    }
}

extension DataManager {
    /// Compares two version strings (e.g., "1.2.0" vs "1.3.0")
    /// Returns:
    /// - `1` if `version1` is greater
    /// - `-1` if `version2` is greater
    /// - `0` if they are equal
    func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 > v2 { return 1 }
            if v1 < v2 { return -1 }
        }

        return 0
    }
    
    func restoreData(from jsonString: String) -> Bool {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return false
        }
        
        do {
            let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

            // Handle bot import separately
            if backupData.type == "bot_import", let bots = backupData.bots {
                storeBotsInUserDefaults(bots)
                print("Bots imported successfully.")
                return true
            }
            
            // ✅ Retrieve current app version and build from Info.plist
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

            // ✅ Retrieve backup version and build (default to 1.0/1 if missing)
            let backupVersion = backupData.version ?? "1.0"
            let backupBuild = backupData.build ?? "1"

            print("📥 Restoring backup. App Version: \(appVersion) (Build \(appBuild)), Backup Version: \(backupVersion) (Build \(backupBuild))")

            // ✅ Compare versions dynamically
            let versionComparison = compareVersions(appVersion, backupVersion)
            let buildComparison = compareVersions(appBuild, backupBuild)

            if versionComparison > 0 || (versionComparison == 0 && buildComparison > 0) {
                os_log("⚠️ Older backup detected (\(backupVersion) Build \(backupBuild)). Performing necessary migrations...")
            } else if versionComparison < 0 || (versionComparison == 0 && buildComparison < 0) {
                print("⚠️ Backup version (\(backupVersion) Build \(backupBuild)) is newer than supported. Some data may not be restored correctly.")
            } else {
                os_log("✔️ Backup version matches the app version.", log: log, type: .info)
            }
            
            resetData()
            
            // Restore spots (Convert CodableSpot to Spot)
            
            for codableSpot in backupData.spots ?? [] {
                let spot = Spot(
                    name: codableSpot.name,
                    address: codableSpot.address,
                    state: codableSpot.state,
                    icon: codableSpot.icon,
                    note: codableSpot.note,
                    isFavorite: codableSpot.isFavorite,
                    latitude: codableSpot.latitude,
                    longitude: codableSpot.longitude,
                    channelId: codableSpot.channelId,
                    imageName: codableSpot.imageName,
                    createdAt: codableSpot.createdAt,
                    updatedAt: codableSpot.updatedAt
                )
                modelContext.insert(spot)
            }

            // Restore friends (Convert CodableFriend to Friend)
            for codableFriend in backupData.friends ?? [] {
                let friend = Friend(
                    name: codableFriend.name,
                    birthday: ISO8601DateFormatter().date(from: codableFriend.birthday) ?? Date(),
                    npub: codableFriend.npub,
                    note: codableFriend.note
                )

                // Restore crypto addresses
                friend.cryptoAddresses = codableFriend.cryptoAddresses.map { codableCrypto in
                    CryptoAddress(
                        address: codableCrypto.address,
                        blockchain: codableCrypto.blockchain,
                        network: codableCrypto.network
                    )
                }

                modelContext.insert(friend)
            }

            // Restore foes (Convert CodableFoe to Foe)
            for codableFoe in backupData.foes ?? [] {
                let foe = Foe(
                    npub: codableFoe.npub,
                    birthday: ISO8601DateFormatter().date(from: codableFoe.birthday) ?? Date(),
                    note: codableFoe.note
                )
                modelContext.insert(foe)
            }

            // Restore Solana key pairs
            let solanaStorage = SolanaKeychainStorage()
            
            for walletData in backupData.solanaKeyPairs ?? [] {
                let keyPair = KeyPair(
                    phrase: walletData.keyPair.phrase,
                    publicKey: walletData.keyPair.publicKey,
                    secretKey: walletData.keyPair.secretKey
                )
                
                try solanaStorage.save(alias: walletData.alias, account: keyPair, network: walletData.network)
            }

            // Restore Nostr key pair
            if let nostrKeyPair = backupData.nostrKeyPairs {
                let nostrStorage = NostrKeychainStorage()
                if let keypair = Keypair(nsec: nostrKeyPair.privateKey) {
                    try nostrStorage.save(keypair)
                }
            }

            // Save the SwiftData context
            try modelContext.save()
            return true
        } catch {
            print("Failed to decode or restore backup data: \(error)")
            return false
        }
    }
    
    private func storeBotsInUserDefaults(_ bots: [CodableBot]) {
        let defaults = UserDefaults.standard
        do {
            let data = try JSONEncoder().encode(bots)
            defaults.set(data, forKey: "importedBots")
        } catch {
            print("Failed to store bots in UserDefaults: \(error)")
        }
    }

    func loadBotsFromUserDefaults() -> [CodableBot] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "importedBots") else { return [] }
        do {
            return try JSONDecoder().decode([CodableBot].self, from: data)
        } catch {
            print("Failed to load bots from UserDefaults: \(error)")
            return []
        }
    }
    
    // MARK: - Reset App
    
    func resetData() {
        keychainForNostr.clear()

        walletManager?.purgeAllAccounts()
        
        do {
            try modelContext.delete(model: Spot.self)
            try modelContext.delete(model: Friend.self)
            try modelContext.delete(model: Foe.self)
        } catch {
            print("Failed to delete data.")
        }
        
        lobby?.clear()
        
        Task {
            await insertDefaultFriend()
        }
    }
}
