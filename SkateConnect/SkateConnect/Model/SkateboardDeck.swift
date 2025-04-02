//
//  SkateboardDeck.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/1/25.
//

import UIKit

struct SkateboardDeck: Codable {
    var imageURL: URL?  // For remote image storage
    var image: UIImage  // Transient property for UI use
    let name: String
    let brand: String
    let width: Double
    let purchaseDate: Date
    let notes: String
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case imageURL, name, brand, width, purchaseDate, notes, createdAt
        // Exclude image from coding
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
    init(imageURL: URL? = nil, image: UIImage, name: String, brand: String, width: Double,
         purchaseDate: Date, notes: String, createdAt: Date) {
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
