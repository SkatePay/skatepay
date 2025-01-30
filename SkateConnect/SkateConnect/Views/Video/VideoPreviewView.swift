//
//  VideoPreviewView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import AVFoundation
import AVKit
import Combine
import ConnectFramework
import SwiftUI

class VideoPlayerViewModel: ObservableObject {
    @Published var isVideoReady = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    // Observe the player's status and handle loading or failure
    func observePlayer(_ player: AVPlayer) {
        isLoading = true // Set loading state

        guard let currentItem = player.currentItem else {
            self.errorMessage = "Failed to load video."
            self.isLoading = false
            return
        }

        currentItem.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    DispatchQueue.main.async {
                        self?.isVideoReady = true
                        self?.isLoading = false
                    }
                case .failed:
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error loading video."
                        self?.isLoading = false
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // Retry loading the video by reinitializing the AVPlayer with a new AVPlayerItem
    func retryLoading(url: URL, player: inout AVPlayer) {
        errorMessage = nil // Clear previous error
        isVideoReady = false // Reset video readiness
        isLoading = true // Start loading

        // Create a new AVPlayerItem to reinitialize the player
        let newItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: newItem)

        // Observe the player and play the video
        observePlayer(player)
        player.play() // Attempt to play the video again
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct VideoPreviewView: View {
    var url: URL?

    @StateObject private var viewModel = VideoPlayerViewModel() // ViewModel for video status
    @State private var player: AVPlayer
    
    @Environment(\.presentationMode) var presentationMode // Environment to control dismissal

    init(url: URL?) {
        self.url = url
        if let validURL = url {
            _player = State(initialValue: AVPlayer(url: validURL))
        } else {
            _player = State(initialValue: AVPlayer()) // Create an empty player for safety
        }
    }

    var body: some View {
        VStack {
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss() // Dismiss the view when back button is pressed
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.leading)
                        Spacer()
                    }
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        // Retry loading the video by passing the current URL
                        if let validURL = url {
                            viewModel.retryLoading(url: validURL, player: &player)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if viewModel.isVideoReady {
                VideoPlayerView(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.play()
                    }
            } else if viewModel.isLoading {
                ProgressView("Loading video...")
                    .padding()
            }
        }
        .onAppear {
            viewModel.observePlayer(player)
        }
    }
}

#Preview {
    VideoPreviewView(url: nil)
}

