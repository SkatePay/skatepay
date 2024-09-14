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
