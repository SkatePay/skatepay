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
    @State private var showingAlert: Bool = false // Show alert on successful upload
    @ObservedObject var cameraViewModel: CameraViewModel // To access the existing video upload logic
    
    init(url: URL?, cameraViewModel: CameraViewModel) {
        self.url = url
        self.cameraViewModel = cameraViewModel
        _player = State(initialValue: AVPlayer(url: url!))
    }
    
    var body: some View {
        VStack {
            VideoPlayerView(player: player)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    player.play()
                }
            
            if let currentFrame = currentFrame {
                Image(uiImage: currentFrame)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .border(Color.gray, width: 1)
            }
            
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
                
                if (currentFrame != nil) {
                    // Post Button (Upload video and image)
                    Button(action: {
                        Task {
                            await postVideoAndImage()
                        }
                    }) {
                        Text("📬 Post")
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
    }
    
    // Function to capture the current frame and save it to disk
    func captureCurrentFrame() {
        guard let asset = player.currentItem?.asset else { return }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = player.currentTime()
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            currentFrame = UIImage(cgImage: cgImage)
            
            if let imageURL = saveImageToDisk(image: currentFrame) {
                print("Frame saved to: \(imageURL)")
            }
        } catch {
            print("Error capturing frame: \(error)")
        }
    }
    
    // Save the UIImage to disk and return the file URL
    func saveImageToDisk(image: UIImage?) -> URL? {
        guard let image = image else { return nil }
        
        var fileName = "frame_\(UUID().uuidString)"
        fileName = url?.deletingPathExtension().lastPathComponent ?? fileName
        fileName += ".jpg"
        
        // Create file path
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
                print("Error saving image: \(error)")
                return nil
            }
        }
        return nil
    }
    
    // Upload video and image
    func postVideoAndImage() async {
        isUploading = true
        cameraViewModel.isUploading = true
        
        do {
            if let currentFrame = currentFrame, let imageURL = saveImageToDisk(image: currentFrame) {
                try await cameraViewModel.uploadFiles(imageURL: imageURL)
            }
        } catch {
            print("Upload failed: \(error)")
            cameraViewModel.isUploading = false
        }
        
        isUploading = false
    }
}

#Preview {
    VideoEditorView(url: nil, cameraViewModel: CameraViewModel())
}
