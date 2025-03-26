//
//  DeckDetailsView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import os

import ConnectFramework
import SwiftUI
import UIKit

struct DeckDetailsView: View {
    let log = OSLog(subsystem: "SkateConnect", category: "DeckTracker")

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var network: Network
    @EnvironmentObject var uploadManager: UploadManager
    
    let deckImage: UIImage
    let fileURL: URL
    
    @State private var deckName: String = ""
    @State private var deckBrand: String = ""
    @State private var deckWidth: Double = 8.0
    @State private var purchaseDate = Date()
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    @State private var isUploading = false
    
    // For width selection
    private let deckWidths = Array(stride(from: 7.5, through: 9.0, by: 0.125))
    
    var body: some View {
        Form {
            // Section 1: Deck Image
            Section {
                Image(uiImage: deckImage)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(90))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
            }
            
            // Rest of your existing code remains the same...
            Section(header: Text("Deck Information")) {
                TextField("Deck Name", text: $deckName)
                TextField("Brand", text: $deckBrand)
                
                Picker("Width (inches)", selection: $deckWidth) {
                    ForEach(deckWidths, id: \.self) { width in
                        Text(String(format: "%.3f", width))
                    }
                }
                
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Deck")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Deck Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveDeck()
                }
                .disabled(deckName.isEmpty)
            }
        }
        .alert("Delete Deck", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteDeck()
            }
        } message: {
            Text("Are you sure you want to delete this deck? This action cannot be undone.")
        }
    }
    
    private func saveDeck() {
        var newDeck = SkateboardDeck(
            id: UUID(),
            imageURL: nil,
            image: deckImage,
            name: deckName,
            brand: deckBrand,
            width: deckWidth,
            purchaseDate: purchaseDate,
            notes: notes,
            createdAt: Date()
        )
                
        if let newDeckJsonString = newDeck.toJSONString() {
            UserDefaults.standard.set(newDeckJsonString, forKey: UserDefaults.Keys.skatedeck)
            os_log("✔️ saving deck: %@ %@", log: log, type: .info, newDeckJsonString, fileURL.absoluteString)
            
            Task {
                let channelId = Constants.CHANNELS.DECKS
                
                try await uploadManager.uploadImage(imageURL: fileURL, channelId: channelId, npub: nil) { isLoading, _ in
                    isUploading = isLoading
                }
                
                let filename = fileURL.lastPathComponent
                let assetURL = "https://\(Constants.S3_BUCKET).s3.us-west-2.amazonaws.com/\(filename)"
                                
                network.publishChannelEvent(channelId: channelId,
                                            kind: .photo,
                                            content: assetURL)
                
                
                newDeck.imageURL = URL(string: assetURL)
                network.publishChannelEvent(channelId: channelId,
                                            kind: .message,
                                            content: newDeckJsonString)
            }
        }
        
        navigation.path.removeLast(2)
    }
    
    private func deleteDeck() {
        // TODO: Delete from your data model
        // For example, remove the deck from your data store
        
        // Navigate back
        navigation.path.removeLast()
    }
}

import UIKit

struct SkateboardDeck: Identifiable, Codable {
    let id: UUID
    var imageURL: URL?  // For remote image storage
    var image: UIImage  // Transient property for UI use
    let name: String
    let brand: String
    let width: Double
    let purchaseDate: Date
    let notes: String
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, imageURL, name, brand, width, purchaseDate, notes, createdAt
        // Exclude image from coding
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        width = try container.decode(Double.self, forKey: .width)
        purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Provide a default image when decoding
        image = UIImage(systemName: "photo")!
    }
    
    // Regular initializer for creating new decks
    init(id: UUID, imageURL: URL? = nil, image: UIImage, name: String, brand: String, width: Double,
         purchaseDate: Date, notes: String, createdAt: Date) {
        self.id = id
        self.imageURL = imageURL
        self.image = image
        self.name = name
        self.brand = brand
        self.width = width
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.createdAt = createdAt
    }
}

extension SkateboardDeck {
    func toJSONString() -> String? {
        let dateFormatter = ISO8601DateFormatter()
        
        // Convert dates to strings
        let purchaseDateString = dateFormatter.string(from: purchaseDate)
        let createdAtString = dateFormatter.string(from: createdAt)
        
        // Create a dictionary with serializable types only
        var deckData: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "brand": brand,
            "width": width,
            "purchaseDate": purchaseDateString,
            "notes": notes,
            "createdAt": createdAtString
        ]
        
        // Add imageURL if present
        if let imageURL = imageURL {
            deckData["imageURL"] = imageURL.absoluteString
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: deckData, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Error converting deck to JSON: \(error)")
            return nil
        }
    }
    
    func loadImageFromURL(completion: @escaping (UIImage?) -> Void) {
        guard let imageURL = imageURL else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, _, error in
            if let data = data, let downloadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(downloadedImage)
                }
            } else {
                print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }.resume()
    }
}
