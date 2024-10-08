//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

func encryptChannelInviteToString(channel: Channel) -> String? {
    let keyString = "SKATECONNECT"
    let keyData = Data(keyString.utf8)
    let hashedKey = SHA256.hash(data: keyData)
    let symmetricKey = SymmetricKey(data: hashedKey)
    
    do {
        let jsonData = try JSONEncoder().encode(channel)
        let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
        return sealedBox.combined?.base64EncodedString()
    } catch {
        print("Error encrypting channel: \(error)")
        return nil
    }
}

func decryptChannelInviteFromString(encryptedString: String) -> Channel? {
    let keyString = "SKATECONNECT"
    let keyData = Data(keyString.utf8)
    let hashedKey = SHA256.hash(data: keyData)
    let symmetricKey = SymmetricKey(data: hashedKey)
    
    do {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            print("Error decoding Base64 string")
            return nil
        }
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        return try JSONDecoder().decode(Channel.self, from: decryptedData)
    } catch {
        print("Error decrypting channel: \(error)")
        return nil
    }
}

struct ToolBoxView: View {    
    @ObservedObject var navigation = Navigation.shared

    @State private var isInviteCopied = false
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
    
    private func createInviteString() -> String {
        var inviteString = navigation.channelId
        
        if let event = navigation.channel {
            inviteString = event.id
            
            if var channel = parseChannel(from: event) {
                channel.event = navigation.channel
                if let ecryptedString = encryptChannelInviteToString(channel: channel) {
                    inviteString = ecryptedString
                }
            }
        }
        return inviteString
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
                        UIPasteboard.general.string = "channel_invite:\(createInviteString())"
                        isInviteCopied = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isInviteCopied = false
                        }
                    }) {
                        VStack {
                            Image(systemName: "link")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            Text("Copy Invite")
                                .font(.caption)
                        }
                    }
                    
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
            
            if isInviteCopied {
                Text("Invite copied!")
                    .foregroundColor(.green)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
            
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
        .animation(.easeInOut, value: isInviteCopied)
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
