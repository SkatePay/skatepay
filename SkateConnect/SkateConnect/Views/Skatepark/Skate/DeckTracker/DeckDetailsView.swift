//
//  DeckDetailsView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI

struct DeckDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: Navigation
    
    let deckImage: UIImage
    @State private var deckName: String = ""
    @State private var deckBrand: String = ""
    @State private var deckWidth: Double = 8.0
    @State private var purchaseDate = Date()
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    
    // For width selection
    private let deckWidths = Array(stride(from: 7.5, through: 9.0, by: 0.125))
    
    var body: some View {
        Form {
            // Section 1: Deck Image
            Section {
                Image(uiImage: deckImage)
                    .resizable()
                    .scaledToFit()
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
            
            // Section 2: Basic Info
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
            
            // Section 3: Additional Notes
            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            // Section 4: Danger Zone
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
        let newDeck = SkateboardDeck(
            id: UUID(),
            image: deckImage,
            name: deckName,
            brand: deckBrand,
            width: deckWidth,
            purchaseDate: purchaseDate,
            notes: notes,
            createdAt: Date()
        )
        
        UserDefaults.standard.set(newDeck.toJSONString(), forKey: UserDefaults.Keys.skatedeck)
        
        // Navigate back or to another appropriate view
        navigation.path.removeLast()
    }
    
    private func deleteDeck() {
        // TODO: Delete from your data model
        // DataStore.shared.removeDeck(deckId)
        
        // Navigate back
        navigation.path.removeLast()
    }
}

// Model for your skateboard deck
struct SkateboardDeck: Identifiable, Codable {
    let id: UUID
    let image: UIImage  // Not codable, marked as transient
    let name: String
    let brand: String
    let width: Double
    let purchaseDate: Date
    let notes: String
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, name, brand, width, purchaseDate, notes, createdAt
        // Exclude image
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        width = try container.decode(Double.self, forKey: .width)
        purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Provide default image
        image = UIImage(systemName: "photo")!
    }
    
    // Regular init for non-decoding use
    init(id: UUID, image: UIImage, name: String, brand: String, width: Double,
         purchaseDate: Date, notes: String, createdAt: Date) {
        self.id = id
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
        
        // Create dictionary with serializable types only
        let deckData: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "brand": brand,
            "width": width,
            "purchaseDate": purchaseDateString,
            "notes": notes,
            "createdAt": createdAtString
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: deckData, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Error converting deck to JSON: \(error)")
            return nil
        }
    }
}
#Preview {
    NavigationStack {
        DeckDetailsView(deckImage: UIImage(systemName: "photo")!)
            .environmentObject(Navigation())
    }
}
