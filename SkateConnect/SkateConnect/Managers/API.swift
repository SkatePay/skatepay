//
//  API.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/28/24.
//

import Combine
import ConnectFramework
import Foundation
import SwiftUI
import SwiftData

public struct Keys: Codable {
    var S3_ACCESS_KEY_ID: String
    var S3_SECRET_ACCESS_KEY: String
}

@MainActor
class API: ObservableObject {
    @Published private var dataManager: DataManager?

    @Published var isLoading = false
    @Published var error: Error?

    let keychainForAws = AwsKeychainStorage()
    
    func setDataManager(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    func fetchLeads() {
        guard let url = URL(string: "\(Constants.API_URL_SKATEPARK)/leads") else {
            self.error = URLError(.badURL)
            self.isLoading = false
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [Lead].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print(error)
                    self?.error = error
                case .finished:
                    break
                }
            } receiveValue: { [weak self] leads in
                self?.dataManager?.createPublicSpots(leads: leads)
                self?.error = nil // Clear any previous errors if successful
            }
            .store(in: &subscriptions)
    }

    func fetchKeys() {
        guard let url = URL(string: "\(Constants.API_URL_SKATEPARK)/keys") else {
            self.error = URLError(.badURL)
            self.isLoading = false
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: Keys.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.error = error
                case .finished:
                    break
                }
            } receiveValue: { [weak self] keys in
                guard let self = self else { return } // Safely unwrap self
                            
                do {
                    try self.keychainForAws.save(keys)
                } catch {
                    print(error)
                }
                
                self.error = nil
            }
            .store(in: &subscriptions)
    }

    private var subscriptions = Set<AnyCancellable>()
}

