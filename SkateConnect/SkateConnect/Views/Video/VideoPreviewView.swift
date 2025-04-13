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
import Photos

class VideoPlayerViewModel: ObservableObject {
    @Published var isVideoReady = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?

    func observePlayer(_ player: AVPlayer) {
        isLoading = true

        guard let currentItem = player.currentItem else {
            self.errorMessage = "Failed to load video."
            self.isLoading = false
            return
        }

        // Observe player status
        currentItem.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isVideoReady = true
                    self?.isLoading = false
                    self?.duration = CMTimeGetSeconds(currentItem.duration)
                case .failed:
                    self?.errorMessage = "Error loading video."
                    self?.isLoading = false
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe playback time
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
            self?.isPlaying = player.rate != 0
        }
    }

    func retryLoading(url: URL, player: inout AVPlayer) {
        errorMessage = nil
        isVideoReady = false
        isLoading = true

        let newItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: newItem)
        observePlayer(player)
        player.play()
    }

    func togglePlayPause(_ player: AVPlayer) {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func seek(to time: Double, player: AVPlayer) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }

    func cleanup(_ player: AVPlayer) {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide default controls
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct VideoPreviewView: View {
    var url: URL?
    @StateObject private var viewModel = VideoPlayerViewModel()
    @State private var player: AVPlayer
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingShareSheet = false
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showControls = true

    init(url: URL?) {
        self.url = url
        if let validURL = url {
            _player = State(initialValue: AVPlayer(url: validURL))
        } else {
            _player = State(initialValue: AVPlayer())
        }
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    Button("Retry") {
                        if let validURL = url {
                            viewModel.retryLoading(url: validURL, player: &player)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else if viewModel.isVideoReady {
                VideoPlayerView(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        videoControlsOverlay
                            .opacity(showControls ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3), value: showControls)
                    )
                    .onTapGesture {
                        showControls.toggle()
                    }
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        viewModel.cleanup(player)
                    }
            } else if viewModel.isLoading {
                ProgressView("Loading video...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }

            if isDownloading {
                ProgressView("Downloading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }

            if let downloadError = downloadError {
                VStack {
                    Text(downloadError)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    Button("Dismiss") {
                        self.downloadError = nil
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .onAppear {
            viewModel.observePlayer(player)
        }
        .navigationBarHidden(true) // Hide the navigation bar to remove the blue "Back" button
        .sheet(isPresented: $isShowingShareSheet) {
            if let validURL = url {
                ShareSheet(activityItems: [validURL])
            }
        }
    }

    private var videoControlsOverlay: some View {
        VStack {
            // Top controls (Back, Share, Download)
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                Spacer()
                HStack(spacing: 20) {
                    Button(action: {
                        isShowingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Button(action: {
                        downloadVideo()
                    }) {
                        Image(systemName: isDownloading ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(isDownloading)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50) // Adjust for safe area

            Spacer()

            // Bottom controls (Play/Pause, Timeline)
            VStack(spacing: 10) {
                Button(action: {
                    viewModel.togglePlayPause(player)
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                        .opacity(0.9)
                }

                HStack {
                    Text(timeString(from: viewModel.currentTime))
                        .foregroundColor(.white)
                        .font(.caption)
                    Slider(value: Binding(
                        get: { viewModel.currentTime },
                        set: { newValue in
                            viewModel.seek(to: newValue, player: player)
                        }
                    ), in: 0...viewModel.duration)
                    .accentColor(.white)
                    Text(timeString(from: viewModel.duration))
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30) // Adjust for safe area
        }
    }

    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func downloadVideo() {
        guard let validURL = url else {
            downloadError = "Invalid video URL."
            return
        }

        isDownloading = true
        downloadError = nil

        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    let task = URLSession.shared.downloadTask(with: validURL) { tempURL, _, error in
                        DispatchQueue.main.async {
                            isDownloading = false
                            if let tempURL = tempURL {
                                do {
                                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                    let destinationURL = documentsPath.appendingPathComponent(validURL.lastPathComponent)
                                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                                    
                                    PHPhotoLibrary.shared().performChanges({
                                        PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: destinationURL, options: nil)
                                    }) { success, error in
                                        DispatchQueue.main.async {
                                            if success {
                                                try? FileManager.default.removeItem(at: destinationURL)
                                            } else {
                                                self.downloadError = error?.localizedDescription ?? "Failed to save video."
                                            }
                                        }
                                    }
                                } catch {
                                    self.downloadError = "Failed to download video."
                                }
                            } else {
                                self.downloadError = error?.localizedDescription ?? "Download failed."
                            }
                        }
                    }
                    task.resume()
                } else {
                    isDownloading = false
                    downloadError = "Photo Library access denied."
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    VideoPreviewView(url: nil)
}

