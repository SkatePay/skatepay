//
//  DataManager.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

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
    @Published private var lobby: Lobby?
    @Published private var walletManager: WalletManager?
    
    private let modelContainer: ModelContainer
    
    let keychainForNostr = NostrKeychainStorage()

    init(inMemory: Bool = false) {
        do {
            self.modelContainer = try ModelContainer(for: Friend.self, Foe.self, Spot.self)
        } catch {
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
                note: "Support Team"
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
    case subscriber
}


struct BackupData: Codable {
    let spots: [CodableSpot]
    let friends: [CodableFriend]
    let foes: [CodableFoe]
    let solanaKeyPairs: [SolanaKeychainStorage.WalletData]
    let nostrKeyPairs: NostrKeypair?
}

extension DataManager {
    func backupData() -> String? {
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
        
        // Create backup data using Codable versions
        let backupData = BackupData(
            spots: codableSpots,
            friends: codableFriends,
            foes: codableFoes,
            solanaKeyPairs: solanaKeyPairs,
            nostrKeyPairs: nostrKeyPair
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
    func restoreData(from jsonString: String) -> Bool {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return false
        }
        
        do {
            let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

            resetData()
            
            // Restore spots (Convert CodableSpot to Spot)
            for codableSpot in backupData.spots {
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
                    imageName: codableSpot.imageName
                )
                modelContext.insert(spot)
            }

            // Restore friends (Convert CodableFriend to Friend)
            for codableFriend in backupData.friends {
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
            for codableFoe in backupData.foes {
                let foe = Foe(
                    npub: codableFoe.npub,
                    birthday: ISO8601DateFormatter().date(from: codableFoe.birthday) ?? Date(),
                    note: codableFoe.note
                )
                modelContext.insert(foe)
            }

            // Restore Solana key pairs
            let solanaStorage = SolanaKeychainStorage()
            for walletData in backupData.solanaKeyPairs {
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
