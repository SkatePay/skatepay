//
//  UserDetails.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/9/24.
//

import os
import NostrSDK
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct UserDetails: View {
    let log = OSLog(subsystem: "SkateConnect", category: "UserDetails")

    @Environment(\.modelContext) private var context
    
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var debugManager: DebugManager
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var uploadManager: UploadManager
        
    @Query(sort: \Friend.npub) private var friends: [Friend]
    @Query(sort: \Foe.npub) private var foes: [Foe]
    
    @State private var isDebugging = false
    @State private var showingConnector = false
    @State private var isFavorite: Bool = false
    @State private var selectedSectionTag: Int = 1
    @State private var isEditing: Bool = false
    @State private var editedUsername: String
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedMediaURL: URL? = nil
    
    @State private var isUploading = false
    @State private var remoteImage: UIImage? // Store the fetched image
    @State private var isLoadingImage = false // Track image loading state

    @StateObject private var eventPublisherForMetadata = MetadataPublisher()
    @StateObject private var eventPublisherForNotes = NotesPublisher()
    
    @StateObject private var eventListenerForNotes = NotesListener()
    @StateObject private var eventListenerForMetadata = MetadataListener()
    
    var user: User
    
    let keychainForNostr = NostrKeychainStorage()
    
    public init(user: User) {
        self.user = user
        self._editedUsername = State(initialValue: user.name)
    }
    
    // Computed property to get the display username
    private var displayUsername: String {
        eventListenerForMetadata.metadata?.name ?? user.name
    }
    
    // Load image from URL asynchronously
    private func loadImageFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            os_log("🔥 Invalid URL: %{public}@", log: log, type: .error, urlString)
            Task { @MainActor in
                isLoadingImage = false
            }
            return
        }
        
        Task { @MainActor in
            isLoadingImage = true
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                Task { @MainActor in
                    remoteImage = uiImage
                    isLoadingImage = false
                }
            } else {
                os_log("🔥 Failed to create UIImage from data", log: log, type: .error)
                Task { @MainActor in
                    isLoadingImage = false
                }
            }
        } catch {
            os_log("🔥 Error loading image: %{public}@", log: log, type: .error, error.localizedDescription)
            Task { @MainActor in
                isLoadingImage = false
            }
        }
    }
    
    // Placeholder functions for business logic
    private func saveUsername(_ newUsername: String) {
        var pictureUrl: URL?
        
        if let pictureUrlString = eventListenerForMetadata.metadata?.picture {
            pictureUrl = URL(string: pictureUrlString)
        }
        
        network.saveMetadata(name: newUsername, pictureURL: pictureUrl)
    }
    
    private func saveProfileImage(_ image: UIImage?) {
        Task {
            if let mediaURL = selectedMediaURL {
                await postSelectedMedia(mediaURL)
            }
        }
    }
    
    var connected: Bool {
        network.relayPool?.relays.contains(where: { $0.url == URL(string: user.relayUrl) }) ?? false
    }
        
    private func isFriend() -> Bool {
        friends.contains(where: { $0.npub == user.npub })
    }
    
    var contact: Friend? {
        friends.first(where: { $0.npub == user.npub })
    }
        
    private func isFoe() -> Bool {
        foes.contains(where: { $0.npub == user.npub })
    }
    
    private func isSupport() -> Bool {
        user.npub == AppData().getSupport().npub
    }
    
    private func getMonkey() -> String {
        isStringOneOfThree(user.name)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Modified profile image section
                Button(action: {
                    if isEditing {
                        showingImagePicker = true
                    }
                }) {
                    ZStack {
                        Group {
                            if isLoadingImage {
                                ProgressView()
                                    .frame(width: 200, height: 200)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            } else if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipShape(Circle())
                            } else if let remoteImage = remoteImage {
                                Image(uiImage: remoteImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipShape(Circle())
                            } else {
                                user.image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipShape(Circle())
                            }
                        }
                        .overlay {
                            Circle().stroke(.white, lineWidth: 4)
                        }
                        .shadow(radius: 7)
                        .overlay(
                            isEditing ? Color.black.opacity(0.3) : Color.clear
                        )
                        
                        if isEditing {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                    }
                }
                .disabled(!isEditing)
                .padding(.top)
                
                // Modified username section
                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        if isEditing {
                            TextField("Username", text: $editedUsername)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 200)
                        } else {
                            Text(displayUsername + " \(getMonkey())")
                                .font(.title)
                                .fontWeight(.medium)
                        }
                        
                        FavoriteButton(isSet: $isFavorite)
                            .onAppear { isFavorite = isFriend() }
                        
                        Spacer()
                    }

                    Text(user.npub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 40)
                        .contextMenu {
                            Button("Copy npub") {
                                UIPasteboard.general.string = user.npub
                            }
                        }
                }

                Divider()

                HStack(spacing: 15) {
                    NavigationLink(value: NavigationPathType.directMessage(user: user)) {
                        Label("Chat", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    if !isSupport() {
                        BlockUnblockButton(user: user)
                            .environmentObject(dataManager)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                TabView(selection: $selectedSectionTag) {
                    deckSectionView
                        .tag(0)
                    infoSectionView
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 300)

                if isDebugging {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        Text("Debug Info")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Relay: \(user.relayUrl) \(connected ? "🟢" : "🔴")")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Profile" : user.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dataManager.isMe(npub: user.npub) {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSupport() {
                        if isEditing {
                            Button("Save") {
                                saveUsername(editedUsername)
                                saveProfileImage(selectedImage)
                                isEditing = false
                            }
                        } else {
                            Button("Edit") {
                                isEditing = true
                                editedUsername = eventListenerForMetadata.metadata?.name ?? user.name
                                selectedImage = nil
                            }
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSupport() && !isEditing {
                    Button {
                        let destination = NavigationPathType.reportUser(
                            user: AppData().getSupport(),
                            message: user.npub
                        )
                        navigation.path.append(destination)
                    } label: {
                        Image(systemName: "exclamationmark.bubble.fill")
                    }
                    .tint(.red)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            FilePicker(selectedMediaURL: $selectedMediaURL)
        }
        .onAppear() {
            guard let publicKey = PublicKey(npub: user.npub) else {
                os_log("🔥 can't get user account", log: log, type: .error)
                return
            }
            
            guard let account = keychainForNostr.account else {
                os_log("🔥 can't get account", log: log, type: .error)
                return
            }

            self.eventListenerForMetadata.setPublicKey(publicKey)
            self.eventListenerForMetadata.setDependencies(dataManager: dataManager, debugManager: debugManager, account: account)
            
            self.eventPublisherForMetadata.subscribeFor(publicKey)
            
            self.eventListenerForNotes.setPublicKey(publicKey)
            self.eventListenerForNotes.setDependencies(dataManager: dataManager, debugManager: debugManager, account: account)
            
            self.eventPublisherForNotes.subscribeFor(publicKey)
            
            isFavorite = isFriend()
            editedUsername = user.name // Initialize on appear
        }
        .onChange(of: eventListenerForMetadata.metadata?.picture) { _, newPictureUrl in
            if let pictureUrl = newPictureUrl {
                Task {
                    await loadImageFromURL(pictureUrl)
                }
            } else {
                Task { @MainActor in
                    remoteImage = nil
                    isLoadingImage = false
                }
            }
        }
        .onChange(of: eventListenerForNotes.receivedEOSE) { _, eoseReceived in
            var showDeckPage = false
            if eoseReceived {
                if let firstNote = self.eventListenerForNotes.notesFromDeckTracker.first, case .deck(_) = firstNote {
                    showDeckPage = true
                }
            }
            self.selectedSectionTag = showDeckPage ? 0 : 1
        }
        .onChange(of: isFavorite) { _, newValue in
            if isSupport() {
                return
            }
            persistFavoriteChange(isNowFavorite: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: UploadNotification.Image)) { notification in
            os_log("🔔 Received UploadNotification.Image", log: log, type: .debug)
            
            guard let assetURLString = notification.userInfo?["assetURL"] as? String else {
                os_log("⚠️ Missing assetURL in uploadImage notification", log: log, type: .error)
                return
            }
            
            guard let npub = notification.userInfo?["npub"] as? String else {
                os_log("⚠️ Missing npub in uploadImage notification", log: log, type: .error)
                return
            }
            
            guard npub == user.npub else {
                os_log("🛑 Ignoring upload notification for different npub: %{public}@", log: log, type: .debug, npub)
                return
            }
            
            guard let pictureURL = URL(string: assetURLString) else {
                os_log("🔥 Invalid assetURL: %{public}@", log: log, type: .error, assetURLString)
                return
            }
            
            network.saveMetadata(name: displayUsername, pictureURL: pictureURL)
            os_log("✅ Metadata saved with pictureURL: %{public}@", log: log, type: .info, pictureURL.absoluteString)
            
            // Load the newly uploaded image
            Task {
                await loadImageFromURL(assetURLString)
            }
        }
    }
    
    private func persistFavoriteChange(isNowFavorite: Bool) {
        if isNowFavorite {
            if dataManager.findFriend(user.npub) == nil {
                let newFriend = Friend(name: user.name, birthday: Date.now, npub: user.npub, note: "")
                context.insert(newFriend)
                os_log("✅ Friend added: %{public}@", log: log, user.npub)
            }
        } else {
            if let friend = dataManager.findFriend(user.npub) {
                context.delete(friend)
                os_log("❌ Friend removed: %{public}@", log: log, user.npub)
            }
        }
    }
    
    private var infoSectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Info")
                .font(.title3)
                .fontWeight(.semibold)
                .gesture(LongPressGesture(minimumDuration: 1.0).onEnded { _ in self.isDebugging = true })

            Group {
                if let contact = contact, !contact.note.isEmpty {
                    Text(contact.note)
                } else {
                    Text(user.note.isEmpty ? "Not provided." : user.note)
                }
            }
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                Button("Copy note") {
                    UIPasteboard.general.string = contact?.note ?? user.note
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var deckSectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Tracked Deck")
                .font(.title3)
                .fontWeight(.semibold)
            DeckView(notes: self.eventListenerForNotes.notesFromDeckTracker)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

extension UserDetails {
    func postSelectedMedia(_ mediaURL: URL) async {
        os_log("⏳ Preparing to upload media: %@", log: log, type: .info, mediaURL.absoluteString)

        let currentNpub = self.user.npub

        guard let fileType = UTType(filenameExtension: mediaURL.pathExtension) else {
            os_log("🛑 Unable to determine file type for: %@", log: log, type: .error, mediaURL.pathExtension)
            return
        }

        // Define handler to update loading state and log errors
        let loadingStateHandler: (Bool, Error?) -> Void = { isLoading, error in
           Task { @MainActor in // Ensure UI updates on main thread
                self.isUploading = isLoading
                if let error = error {
                    // Error occurred during upload process (reported by uploadManager)
                    os_log("🛑 Upload failed: %@", log: log, type: .error, error.localizedDescription)
                    // Optionally update UI further based on error
                }
            }
        }

        do {
            if fileType.conforms(to: .image) {
                os_log("⏳ Uploading image for npub=[%@]", log: log, type: .info, currentNpub)
                try await uploadManager.uploadImage(
                    imageURL: mediaURL,
                    channelId: nil,
                    npub: currentNpub,
                    onLoadingStateChange: loadingStateHandler
                )
                
                os_log("✔️ Image upload successful: %@", log: log, type: .info, mediaURL.lastPathComponent)

                var userInfo: [String: Any] = [:]

                userInfo["npub"] = currentNpub

                navigation.completeUpload(imageURL: mediaURL, userInfo: userInfo)
            } else {
                os_log("🛑 Unsupported file type: %@", log: log, type: .error, fileType.identifier)
                // Maybe set isUploading = false here if it was set true previously
            }
        } catch {
            // Catch errors thrown directly by uploadManager methods (e.g., setup errors)
            // or errors during the await itself.
            os_log("🛑 Upload execution failed: %@", log: log, type: .error, error.localizedDescription)
            // Ensure loading state is false if an error is caught here
             Task { @MainActor in
                 if self.isUploading {
                     self.isUploading = false
                 }
             }
             // Optionally display an error message to the user
        }
    }
}

struct BlockUnblockButton: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var dataManager: DataManager

    var user: User

    var body: some View {
        Group {
            if let foe = dataManager.findFoes(user.npub) {
                Button("Unmute", role: .destructive) {
                    context.delete(foe)
                }
            } else {
                Button("Mute") {
                    let newFoe = Foe(npub: user.npub, birthday: Date.now, note: "")
                    context.insert(newFoe)
                    NotificationCenter.default.post(name: .muteUser, object: nil, userInfo: ["npub": user.npub])
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
}


struct DeckView: View {
    var notes: [NoteType] = []

    var body: some View {
        if let firstNote = notes.first {
            switch firstNote {
            case .deck(let deck):
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if let url = deck.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        ProgressView()
                                    }
                                case .success(let loadedImage):
                                    loadedImage
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        Image(systemName: "photo.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                             ZStack {
                                Color(.secondarySystemBackground)
                                Image(uiImage: deck.image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
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
//                            Text("Purchased:")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                            Text(deck.purchaseDate, style: .date)
//                                .font(.caption)

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
        }
    }
}
