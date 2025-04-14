//
//  DeckView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 4/13/25.
//

import SwiftUI
import os

struct DeckView: View {
    @EnvironmentObject private var navigation: Navigation

    var notes: [NoteType] = []
    var user: User?
    
    @State private var showZoomedImage = false
    @State private var zoomItem: ZoomItem?
    
    private let log = OSLog(subsystem: "SkateConnect", category: "DeckView")
    
    // Enum to represent either a URL or UIImage for zoom
    private enum ZoomItem {
        case url(URL)
        case uiImage(UIImage)
    }
    
    var body: some View {
        if let firstNote = notes.first {
            switch firstNote {
            case .deck(let deck):
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if let url = deck.imageURL, !url.absoluteString.isEmpty {
                            Button(action: {
                                os_log("📸 Opening zoom view with URL: %{public}@", log: log, type: .debug, url.absoluteString)
                                zoomItem = .url(url)
                                showZoomedImage = true
                            }) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            Color(.secondarySystemBackground)
                                            ProgressView()
                                        }
                                        .onAppear {
                                            os_log("⏳ Loading image from URL: %{public}@", log: log, type: .debug, url.absoluteString)
                                        }
                                    case .success(let loadedImage):
                                        loadedImage
                                            .resizable()
                                            .scaledToFit()
                                        .onAppear {
                                            os_log("✅ Image loaded from URL: %{public}@", log: log, type: .info, url.absoluteString)
                                        }
                                    case .failure(let error):
                                        ZStack {
                                            Color(.secondarySystemBackground)
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(.red)
                                                .padding()
                                        }
                                        .onAppear {
                                            os_log("🔥 Failed to load image from URL: %{public}@, error: %{public}@", log: log, type: .error, url.absoluteString, error.localizedDescription)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                            .disabled(url.absoluteString.isEmpty)
                        } else if deck.image.pngData() != nil {
                            Button(action: {
                                os_log("📸 Opening zoom view with UIImage", log: log, type: .debug)
                                zoomItem = .uiImage(deck.image)
                                showZoomedImage = true
                            }) {
                                ZStack {
                                    Color(.secondarySystemBackground)
                                    Image(uiImage: deck.image)
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                }
                            }
                        } else {
                            ZStack {
                                Color(.secondarySystemBackground)
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                            .onAppear {
                                os_log("⚠️ No valid image or URL for deck", log: log, type: .debug)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 4)
                    
                    Text(deck.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(deck.brand.isEmpty ? "Unknown Brand" : deck.brand)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(deck.width, specifier: "%.3f")\" Wide")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !deck.notes.isEmpty {
                            Text("Notes:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(deck.notes)
                                .font(.body)
                            Divider().padding(.vertical, 2)
                        }
                        
                        HStack {
                            Spacer()
                            Text("Added:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(deck.createdAt, style: .date)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                .sheet(isPresented: $showZoomedImage) {
                    if let item = zoomItem {
                        switch item {
                        case .url(let url):
                            ZoomableImageView(imageURL: url, uiImage: nil)
                        case .uiImage(let image):
                            ZoomableImageView(imageURL: nil, uiImage: image)
                        }
                    } else {
                        ZoomableImageView(imageURL: nil, uiImage: nil)
                    }
                }
                .onChange(of: showZoomedImage) { _, newValue in
                    if !newValue {
                        zoomItem = nil
                        os_log("🧹 Cleared zoomItem after dismissing ZoomableImageView", log: log, type: .debug)
                    }
                }
                .onAppear {
                    os_log("🃏 DeckView appeared with %d notes", log: log, type: .debug, notes.count)
                }
            case .unknown:
                Text("No deck information found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } else {
            Text("No decks available.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .onAppear {
                    os_log("⚠️ No notes available in DeckView", log: log, type: .debug)
                }
            
            if let user = self.user {
                if (navigation.isMe(npub: user.npub)) {
                    Button(action: {
                        navigation.path.append(NavigationPathType.deckTracker)
                    }) {
                        HStack {
                            Image(systemName: "skateboard.fill") // Optional icon
                            Text("Add Deck")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center) // Center the button
                    .padding()
                }
            }
        }
    }
}

// Custom image loader to handle URL requests with timeout
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var error: Error?
    @Published var isLoading = false
    
    private let log = OSLog(subsystem: "SkateConnect", category: "ImageLoader")
    
    func load(from url: URL, timeout: TimeInterval = 10.0) {
        isLoading = true
        error = nil
        image = nil
        
        os_log("📡 Starting image load: %{public}@", log: log, type: .debug, url.absoluteString)
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                    os_log("🔥 Image load failed: %{public}@, error: %{public}@", log: self?.log ?? .default, type: .error, url.absoluteString, error.localizedDescription)
                    return
                }
                
                guard let data = data, let uiImage = UIImage(data: data) else {
                    let error = NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    self?.error = error
                    os_log("🔥 Image load failed: %{public}@, error: Invalid image data", log: self?.log ?? .default, type: .error, url.absoluteString)
                    return
                }
                
                self?.image = uiImage
                os_log("✅ Image loaded successfully: %{public}@", log: self?.log ?? .default, type: .info, url.absoluteString)
            }
        }
        
        task.resume()
    }
}

struct ZoomableImageView: View {
    let imageURL: URL?
    let uiImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = ImageLoader()
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let padding: CGFloat = 20
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Group {
                    if loader.isLoading {
                        ProgressView()
                    } else if let image = loader.image {
                        imageView(for: Image(uiImage: image), in: proxy)
                    } else if let image = uiImage {
                        imageView(for: Image(uiImage: image), in: proxy)
                    } else if loader.error != nil {
                        errorView
                    } else {
                        errorView
                    }
                }
                
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.white.opacity(0.8))
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            if let url = imageURL, uiImage == nil {
                loader.load(from: url)
            }
        }
    }
    
    private func imageView(for image: Image, in proxy: GeometryProxy) -> some View {
        // Calculate the initial scale to fit the image within the available space
        let availableWidth = proxy.size.width - (padding * 2)
        let availableHeight = proxy.size.height - (padding * 2)
        
        return image
            .resizable()
            .scaledToFit()
            .frame(width: availableWidth, height: availableHeight)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, minScale), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        withAnimation {
                            if scale <= minScale {
                                scale = minScale
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { gesture in
                        let newOffset = CGSize(
                            width: lastOffset.width + gesture.translation.width,
                            height: lastOffset.height + gesture.translation.height
                        )
                        offset = newOffset
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation {
                            if scale > minScale {
                                scale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
                .frame(width: 100, height: 100)
            Text("Unable to load image")
                .foregroundColor(.white)
                .font(.headline)
            if let error = loader.error {
                Text(error.localizedDescription)
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            if imageURL != nil {
                Button("Retry") {
                    if let url = imageURL {
                        loader.load(from: url)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}
