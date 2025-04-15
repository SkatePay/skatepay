//
//  VideoEditorView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/27/24.
//

import AVFoundation
import AVKit
import SwiftData
import SwiftUI

struct VideoEditorView: View {
    var url: URL?
    
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var uploadManager: UploadManager
    @Environment(\.modelContext) private var context
    
    @State private var player: AVPlayer
    @State private var currentFrame: UIImage?
    @State private var isUploading: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSpotSelector: Bool = false
    @State private var selectedSpot: Spot?
    
    @Query(filter: #Predicate<Spot> { $0.channelId != "" }) private var spots: [Spot]
    
    @ObservedObject var cameraViewModel: CameraViewModel
    
    private let lastSelectedSpotKey = "LastSelectedSpotChannelId"
    
    init(url: URL?, cameraViewModel: CameraViewModel) {
        self.url = url
        self.cameraViewModel = cameraViewModel
        _player = State(initialValue: AVPlayer(url: url!))
    }
    
    var body: some View {
        ZStack {
            VStack {
                // Video Player
                VideoPlayerView(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.play()
                    }
                
                // Captured Frame Preview
                if let currentFrame = currentFrame {
                    Image(uiImage: currentFrame)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .border(Color.gray, width: 1)
                }
                
                // Buttons for Frame Capture and Upload
                HStack {
                    // Pick Frame Button
                    Button(action: {
                        captureCurrentFrame()
                    }) {
                        Text("Pick Frame")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(isUploading)
                    
                    Spacer()
                    
                    // Post Button (Upload video and image)
                    if currentFrame != nil {
                        Button(action: {
                            Task {
                                if navigation.channelId == nil {
                                    showSpotSelector = true
                                } else {
                                    await postVideoAndImage()
                                }
                            }
                        }) {
                            Text(isUploading ? "Uploading..." : "📬 Post")
                                .font(.headline)
                                .padding()
                                .background(isUploading ? Color.gray : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                        .disabled(isUploading)
                    }
                }
            }
            
            // Custom Alert for Spot Selection
            if showSpotSelector {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSpotSelector = false
                    }
                
                VStack(spacing: 20) {
                    Text("Select a Spot")
                        .font(.headline)
                    
                    if spots.isEmpty {
                        Text("No spots available")
                            .foregroundColor(.gray)
                    } else {
                        // Caption above the Picker
                        Text("Select Spot Channel")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        Picker("Spots", selection: $selectedSpot) {
                            ForEach(spots) { spot in
                                Text(spot.name)
                                    .tag(spot as Spot?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            showSpotSelector = false
                        }
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("OK") {
                            if let selectedSpot = selectedSpot {
                                UserDefaults.standard.set(selectedSpot.channelId, forKey: lastSelectedSpotKey)
                                navigation.channelId = selectedSpot.channelId
                                Task {
                                    await postVideoAndImage()
                                }
                            }
                            showSpotSelector = false
                        }
                        .padding()
                        .background(spots.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(spots.isEmpty)
                    }
                }
                .padding()
                .frame(width: 300)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(radius: 10)
                .onAppear {
                    if let lastChannelId = UserDefaults.standard.string(forKey: lastSelectedSpotKey) {
                        if let matchingSpot = spots.first(where: { $0.channelId == lastChannelId }) {
                            selectedSpot = matchingSpot
                        } else {
                            selectedSpot = spots.first
                        }
                    } else {
                        selectedSpot = spots.first
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Capture Current Frame
    func captureCurrentFrame() {
        guard let asset = player.currentItem?.asset else {
            showError(message: "Failed to access video asset.")
            return
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = player.currentTime()
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            currentFrame = UIImage(cgImage: cgImage)
            
            if let imageURL = saveImageToDisk(image: currentFrame) {
                print("Frame saved to: \(imageURL)")
            } else {
                showError(message: "Failed to save frame to disk.")
            }
        } catch {
            showError(message: "Error capturing frame: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Image to Disk
    func saveImageToDisk(image: UIImage?) -> URL? {
        guard let image = image else {
            showError(message: "No image to save.")
            return nil
        }
        
        let videoFileName = url?.deletingPathExtension().lastPathComponent ?? "frame_\(UUID().uuidString)"
        let fileName = "\(videoFileName).jpg"
        
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if let jpegData = image.jpegData(compressionQuality: 1.0) {
            do {
                try jpegData.write(to: fileURL)
                return fileURL
            } catch {
                showError(message: "Error saving image: \(error.localizedDescription)")
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Upload Video and Image
    func postVideoAndImage() async {
        do {
            if let currentFrame = currentFrame, let imageURL = saveImageToDisk(image: currentFrame) {
                try await uploadManager.uploadFiles(imageURL: imageURL) { isLoading, _ in
                    isUploading = isLoading
                }
            } else {
                showError(message: "Failed to save image for upload.")
            }
        } catch {
            showError(message: "Upload failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Show Error Alert
    func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}

#Preview {
    VideoEditorView(url: nil, cameraViewModel: CameraViewModel())
}
