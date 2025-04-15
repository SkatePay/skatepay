//
//  EditChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import MapKit
import NostrSDK
import SwiftUI

struct EditChannel: View, EventCreating {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var navigation: Navigation
    
    @State private var isInviteCopied = false
    @State private var isEditingName = false
    @State private var isEditingDescription = false
    @State private var showSaveConfirmation = false
    
    let keychainForNostr = NostrKeychainStorage()
    
    private var channel: Channel?
    
    // Draft state
    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    
    // Original state (loaded once)
    @State private var originalName: String = ""
    @State private var originalDescription: String = ""
    @State private var originalLocation: CLLocationCoordinate2D?
    
    init(channel: Channel?) {
        self.channel = channel
    }
    
    private func createInviteString() -> String {
        guard let channelId = channel?.creationEvent?.id else { return "" }
        if let channel = channel,
           let encryptedString = MessageHelper.encryptChannelInviteToString(channel: channel) {
            return encryptedString
        }
        return channelId
    }
    
    private var isChannelOwner: Bool {
        guard let pubkey = channel?.creationEvent?.pubkey,
              let publicKeyForMod = PublicKey(hex: pubkey),
              let npub = keychainForNostr.account?.publicKey.npub else {
            return false
        }
        return publicKeyForMod.npub == npub
    }
    
    // Show save only when edits are confirmed and changes exist
    private var canSaveChanges: Bool {
        !isEditingName && !isEditingDescription && hasPendingChanges
    }
    
    var body: some View {
        VStack {
            if let channel = channel {
                Form {
                    Text("📜 Spot Info")
                    
                    // MARK: Name Section
                    Section("Name") {
                        HStack(alignment: .top) {
                            if isEditingName {
                                TextField("Channel Name", text: $draftName)
                                    .font(.body)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3))
                                    )
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    isEditingName = false
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                            } else {
                                Text(draftName)
                                    .font(.body)
                                    .contextMenu {
                                        Button("Copy name") {
                                            UIPasteboard.general.string = draftName
                                        }
                                    }
                                
                                Spacer()
                                
                                if isChannelOwner {
                                    Button(action: {
                                        isEditingName = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: Description Section
                    Section("Description") {
                        HStack(alignment: .top) {
                            if isEditingDescription {
                                TextEditor(text: $draftDescription)
                                    .frame(minHeight: 100)
                                    .font(.body)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Button(action: {
                                    isEditingDescription = false
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                            } else {
                                Text(draftDescription)
                                    .font(.body)
                                    .contextMenu {
                                        Button("Copy description") {
                                            UIPasteboard.general.string = draftDescription
                                        }
                                    }
                                
                                Spacer()
                                
                                if isChannelOwner {
                                    Button(action: {
                                        isEditingDescription = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: Location Section
                    if let location = originalLocation {
                        Section("Location") {
                            HStack(alignment: .top) {
                                let locationString = "📍 Location: \(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude))"
                                Text(locationString)
                                    .font(.body)
                                    .contextMenu {
                                        Button("Copy location") {
                                            UIPasteboard.general.string = locationString
                                        }
                                    }
                                Spacer()
                            }
                        }
                    }
                    
                    // MARK: Channel ID Section
                    
                    if let creationEvent = channel.creationEvent {
                        Section("Id") {
                            Text(creationEvent.id)
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = "channel_invite:\(createInviteString())"
                                        isInviteCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            isInviteCopied = false
                                        }
                                    } label: {
                                        VStack {
                                            Image(systemName: "link")
                                                .resizable()
                                                .frame(width: 40, height: 40)
                                                .foregroundColor(.blue)
                                            Text("Copy Invite").font(.caption)
                                        }
                                    }
                                    
                                    Button("Copy spotId") {
                                        guard let channelId = channel.creationEvent?.id else { return }
                                        UIPasteboard.general.string = channelId
                                    }
                                }
                            
                            
                            
                            // MARK: Owner Info
                            if let publicKeyForMod = PublicKey(hex: creationEvent.pubkey),
                               let npub = keychainForNostr.account?.publicKey.npub {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(publicKeyForMod.npub == npub ? "Owner: You" : "Owner: \(MainHelper.friendlyKey(npub: publicKeyForMod.npub))")
                                        .contextMenu {
                                            Button("Copy npub") {
                                                UIPasteboard.general.string = publicKeyForMod.npub
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    if originalName.isEmpty {
                        originalName = channel.metadata?.name ?? channel.name
                        draftName = originalName
                    }
                    
                    if originalDescription.isEmpty {
                        let about = channel.metadata?.about ?? channel.about
                        
                        if let decodedAbout = ChannelHelper.decodeAbout(about) {
                            originalDescription = decodedAbout.description
                            originalLocation = decodedAbout.location
                        }
                        
                        draftDescription = originalDescription
                    }
                }
                
                // MARK: Save Button
                if canSaveChanges {
                    Button(action: {
                        saveDraftChanges()
                        showSaveConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Changes")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    .alert("Changes Saved", isPresented: $showSaveConfirmation) {
                        Button("OK", role: .cancel) {
                            dismiss()
                        }
                    }
                } else {
                    if let creationEvent = channel.creationEvent, let npub = keychainForNostr.account?.publicKey.npub {
                        if navigation.isMe(pubkey: creationEvent.pubkey) {
                            Button(action: {
                                if let url = URL(string: "https://skateconnect.app/spot?npub=\(npub)&spot_id=\(creationEvent.id)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "globe") // Optional icon
                                    Text("Publish My Spot")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    }
                }
            }
            
            if isInviteCopied {
                Text("Invite copied!")
                    .foregroundColor(.green)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isInviteCopied)
    }
    
    // MARK: Change Detection
    private var hasPendingChanges: Bool {
        draftName != originalName || draftDescription != originalDescription
    }
    
    // MARK: Save Logic
    private func saveDraftChanges() {
        guard let aboutDecoded = channel?.aboutDecoded else {
            print("Missing channel metadata or account")
            return
        }
        
        let aboutStructure = AboutStructure(
            description: draftDescription,
            location: aboutDecoded.location,
            note: aboutDecoded.note
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let aboutData = try? encoder.encode(aboutStructure),
              let aboutJSONString = String(data: aboutData, encoding: .utf8) else {
            print("Encoding aboutStructure failed")
            return
        }
        
        guard var channel = self.channel else { return }
        
        let metadata = ChannelMetadata(
            name: draftName,
            about: aboutJSONString,
            picture: channel.picture,
            relays: channel.relays
        )
        
        channel.metadata = metadata
        
        NotificationCenter.default.post(
            name: .saveChannelMetadata,
            object: nil,
            userInfo: [
                "channel": channel
            ]
        )
    }
}
