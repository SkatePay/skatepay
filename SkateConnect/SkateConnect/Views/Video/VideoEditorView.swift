//
//  VideoEditorView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/27/24.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoEditorView: View {
    var url: URL?
    
    @State private var player: AVPlayer
    @State private var currentFrame: UIImage? // Store the captured frame
    @State private var isUploading: Bool = false // Manage upload state
    @State private var showErrorAlert: Bool = false // Show error alerts
    @State private var errorMessage: String = "" // Error message for alerts
    @ObservedObject var cameraViewModel: CameraViewModel // To access the existing video upload logic
    
    init(url: URL?, cameraViewModel: CameraViewModel) {
        self.url = url
        self.cameraViewModel = cameraViewModel
        _player = State(initialValue: AVPlayer(url: url!))
    }
    
    var body: some View {
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
                
                Spacer()
                
                // Post Button (Upload video and image)
                if currentFrame != nil {
                    Button(action: {
                        Task {
                            await postVideoAndImage()
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
                    .disabled(isUploading) // Disable button when uploading
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
            
            // Save the captured frame to disk
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
        
        // Extract the video file name (without extension)
        let videoFileName = url?.deletingPathExtension().lastPathComponent ?? "frame_\(UUID().uuidString)"
        
        // Create the image file name (same as video, but with .jpg extension)
        let fileName = "\(videoFileName).jpg"
        
        // Save the image to the documents directory
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Convert UIImage to JPEG data
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
        isUploading = true
        cameraViewModel.isUploading = true
        
        do {
            if let currentFrame = currentFrame, let imageURL = saveImageToDisk(image: currentFrame) {
                try await cameraViewModel.uploadFiles(imageURL: imageURL)
            } else {
                showError(message: "Failed to save image for upload.")
            }
        } catch {
            showError(message: "Upload failed: \(error.localizedDescription)")
        }
        
        isUploading = false
        cameraViewModel.isUploading = false
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
