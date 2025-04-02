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
    
    private let deckTrackerNoteKind = "DeckTracker"
    
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
            imageURL: nil,
            image: deckImage,
            name: deckName,
            brand: deckBrand,
            width: deckWidth,
            purchaseDate: purchaseDate,
            notes: notes,
            createdAt: Date()
        )
        
        Task {
            let channelId = Constants.CHANNELS.DECKS
            var assetURLString: String? = nil
            
            do {
                try await uploadManager.uploadImage(imageURL: fileURL, channelId: channelId, npub: nil) { isLoading, _ in
                    Task { @MainActor in
                        isUploading = isLoading
                    }
                }
                
                let filename = fileURL.lastPathComponent
                assetURLString = "https://\(Constants.S3_BUCKET).s3.us-west-2.amazonaws.com/\(filename)"
                
                if let finalURL = URL(string: assetURLString!) {
                    newDeck.imageURL = finalURL
                } else {
                    os_log("❌ Could not create URL from asset string: %@", log: log, type: .error, assetURLString ?? "nil")
                }
                
                guard let finalDeckJsonString = newDeck.toJSONString() else {
                    os_log("❌ Failed to serialize final deck object to JSON", log: log, type: .error)
                    // Handle error appropriately (e.g., show alert, stop process)
                    Task { @MainActor in isUploading = false }
                    return // Stop execution
                }
                
                UserDefaults.standard.set(finalDeckJsonString, forKey: UserDefaults.Keys.skatedeck)
                os_log("✔️ Saving deck locally: %@", log: log, type: .info, finalDeckJsonString)
                
                let noteToPost = Note(kind: deckTrackerNoteKind, text: finalDeckJsonString)
                
                guard let noteJsonString = noteToPost.toJSONString() else {
                    os_log("❌ Failed to serialize Note object to JSON", log: log, type: .error)
                    // Handle error appropriately
                    Task { @MainActor in isUploading = false }
                    return // Stop execution
                }
                
                os_log("✔️ Posting Note: %@", log: log, type: .info, noteJsonString)
                network.postNote(text: noteJsonString)
            } catch {
                os_log("❌ Failed to upload image or publish event: %@", log: log, type: .error, error.localizedDescription)
                Task { @MainActor in
                    isUploading = false
                }
            }
            
            await MainActor.run {
                isUploading = false
                navigation.path.removeLast(2)
            }
        }
    }
    
    private func deleteDeck() {
        // TODO: Implement deletion logic for both local storage and potentially network
        os_log("🗑️ Deleting deck (implementation pending)", log: log, type: .info)
        UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.skatedeck) // Example: Remove from UserDefaults
        // Add network call to delete/invalidate the note if necessary

        navigation.path.removeLast()
    }
}
