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

    private var cancellables = Set<AnyCancellable>()

    func observePlayer(_ player: AVPlayer) {
        guard let currentItem = player.currentItem else {
            self.errorMessage = "Failed to load video."
            return
        }

        currentItem.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    DispatchQueue.main.async {
                        self?.isVideoReady = true
                    }
                case .failed:
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error loading video."
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// For SwiftUI to use UIKit's AVPlayerViewController, we need this wrapper:
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

    init(url: URL?) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url!))
    }

    var body: some View {
        VStack {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.isVideoReady {
                VideoPlayerView(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.play()
                    }
            } else {
                ProgressView("Loading video...")
                    .padding()
            }
        }
        .onAppear {
            viewModel.observePlayer(player) // Observe the player's status when the view appears
        }
    }
}

#Preview {
    VideoPreviewView(url: nil)
}
