//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolBoxView: View {    
    @EnvironmentObject var navigation: Navigation

    @State private var showingFilePicker = false
    @State private var selectedMediaURL: URL? = nil
    
    let keychainForAws = AwsKeychainStorage()
    private let uploadManager: UploadManager

    init() {
        uploadManager = UploadManager(keychainForAws: keychainForAws)
    }
    
    private var channelId: String {
        navigation.channel?.id ?? ""
    }
    
    var body: some View {
        VStack {
            Text("🧰 Toolbox")
                .font(.headline)
                .padding(.top)
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.green)
                            Text("Add File")
                                .font(.caption)
                        }
                    }
                    .sheet(isPresented: $showingFilePicker) {
                        FilePicker(selectedMediaURL: $selectedMediaURL)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            if let mediaURL = selectedMediaURL {
                Text("Selected Media: \(mediaURL.lastPathComponent)")
                    .padding(.top, 10)
                
                Button(action: {
                    Task {
                        await postSelectedMedia(mediaURL)
                    }
                }) {
                    Text("Upload Media")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.bottom, 20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
    }
    
    // Async function to post the selected media
    func postSelectedMedia(_ mediaURL: URL) async {
        // Call the upload function from cameraViewModel or handle the media upload here
        print("Uploading media from URL: \(mediaURL)")
        
        // Determine if the file is an image or video using UTType
        let fileType = UTType(filenameExtension: mediaURL.pathExtension)

        do {
            if let fileType = fileType {
                if fileType.conforms(to: .image) {
                    print("Detected image file")
                    // Upload the image
                    try await uploadManager.uploadImage(imageURL: mediaURL, channelId: channelId)
                    navigation.completeUpload(imageURL: mediaURL)
                    
                } else if fileType.conforms(to: .movie) {
                    print("Detected video file")
                    // Upload the video
                    try await uploadManager.uploadVideo(videoURL: mediaURL, channelId: channelId)
                    
                    navigation.completeUpload(videoURL: mediaURL)
                } else {
                    print("Unsupported file type")
                }
            } else {
                print("Unable to determine file type")
            }
        } catch {
            print("Error uploading media: \(error)")
        }
    }
}

#Preview {
    ToolBoxView()
}
