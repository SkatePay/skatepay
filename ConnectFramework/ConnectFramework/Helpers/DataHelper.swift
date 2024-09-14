//
//  DataHelper.swift
//  ConnectFramework
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import CoreLocation
import Foundation

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

public func coordinateToJSONString(_ coordinate: CLLocationCoordinate2D) -> String? {
     let location = Location(from: coordinate)
     
     do {
         let jsonData = try JSONEncoder().encode(location)
         let jsonString = String(data: jsonData, encoding: .utf8)
         return jsonString
     } catch {
         print("Error encoding coordinate to JSON: \(error)")
         return nil
     }
}

public func convertStringToCoordinate(_ coordinateString: String) -> CLLocationCoordinate2D? {
    let cleanedString = coordinateString.replacingOccurrences(of: "\\s", with: "", options: .regularExpression, range: nil)
    
    guard let data = cleanedString.data(using: .utf8) else {
        print("Failed to convert string to data")
        return nil
    }
    
    do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Double] {
            // Extract latitude and longitude
            guard let latitude = json["latitude"],
                  let longitude = json["longitude"] else {
                print("Missing latitude or longitude in JSON")
                return nil
            }
            
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            print("JSON serialization failed or not in expected format")
            return nil
        }
    } catch {
        print("Error parsing JSON: \(error)")
        return nil
    }
}

public func load<T: Decodable>(_ filename: String) -> T {
    let data: Data
    
    guard let file = Bundle(identifier: "ai.prorobot.ConnectFramework")?.url(forResource: filename, withExtension: nil)
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }


    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }


    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}
