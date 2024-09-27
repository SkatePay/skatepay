//
//  CameraInputView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/25/24.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Vision

struct CameraInputView: View {
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var inputText = ""
//    @State private var attachments: [Attachment] = []

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.showCamera.toggle()
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.gray)
                }
                .sheet(isPresented: $showCamera) {
                    CameraView()
                }

                TextField("Type your message", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }

            Button(action: sendMessage) {
                Text("Send")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(inputText.isEmpty)
        }
        .photosPicker(isPresented: $isShowingImagePicker, selection: $selectedItem)
        .onChange(of: selectedItem) {
            Task {
                if let item = selectedItem,
                   let data = try? await item.loadTransferable(type: Data.self) {
//                    if let uiImage = UIImage(data: data) {
//                        selectedImage = Image(uiImage: uiImage)
//                    }
                } else {
                    print("Failed to load image data")
                }
            }
        }
    }

    func sendMessage() {
        // Logic to send message and attachments
    }
}

#Preview {
    CameraInputView()
}
