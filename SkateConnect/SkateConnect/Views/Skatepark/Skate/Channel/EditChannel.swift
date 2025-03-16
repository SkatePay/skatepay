//
//  EditChannel.swift
//  SkatePay
//
//  Created by Konstantin Yurchenko, Jr on 9/12/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI

struct EditChannel: View, EventCreating {
    @Environment(\.modelContext) private var context
    
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
    
    private func decodeAbout(_ about: String?) -> String {
        guard let about = about else { return "" }
        do {
            let decoder = JSONDecoder()
            let decodedStructure = try decoder.decode(AboutStructure.self, from: about.data(using: .utf8)!)
            return decodedStructure.description
        } catch {
            return ""
        }
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
                    Text("📡 Channel Info")
                    
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
                                    
                                    Button("Copy channelId") {
                                        guard let channelId = channel.creationEvent?.id else { return }
                                        UIPasteboard.general.string = channelId
                                    }
                                }
                            
                            
                            
                            // MARK: Owner Info
                            if let publicKeyForMod = PublicKey(hex: creationEvent.pubkey),
                               let npub = keychainForNostr.account?.publicKey.npub {
                                Text(publicKeyForMod.npub == npub ? "Owner: You" : "Owner: \(MainHelper.friendlyKey(npub: publicKeyForMod.npub))")
                                    .contextMenu {
                                        Button("Copy npub") {
                                            UIPasteboard.general.string = publicKeyForMod.npub
                                        }
                                    }
                            }
                        }
                        
                        // MARK: Private Channel Shortcut
                        if channel.name == "Private Channel" {
                            let spot = Spot(
                                name: "Private Channel \(creationEvent.id.suffix(3))",
                                address: "", state: "", icon: "", note: "",
                                latitude: AppData().landmarks[0].locationCoordinate.latitude,
                                longitude: AppData().landmarks[0].locationCoordinate.longitude,
                                channelId: creationEvent.id
                            )
                            
                            Button("Add to Address Book") {
                                context.insert(spot)
                            }
                        }
                    }
                }
                .onAppear {
                    if originalName.isEmpty {
                        originalName = channel.name
                        draftName = channel.name
                    }
                    
                    if originalDescription.isEmpty {
                        originalDescription = decodeAbout(channel.about)
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
                        Button("OK", role: .cancel) { }
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
        print("Saving -> Name: \(draftName), Description: \(draftDescription)")
        
        guard let aboutDecoded = channel?.aboutDecoded else {
            return
        }
        
        var about = originalDescription
        
        let aboutStructure = AboutStructure(
            description: draftDescription,
            location: aboutDecoded.location,
            note: aboutDecoded.note
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(aboutStructure)
            about = String(data: data, encoding: .utf8) ?? originalDescription
        } catch {
            print("Error encoding: \(error)")
        }
        
        if let account = keychainForNostr.account {
            do {
                let metadata = ChannelMetadata(
                    name: draftName,
                    about: about,
                    picture: Constants.PICTURE_RABOTA_TOKEN,
                    relays: [Constants.RELAY_URL_SKATEPARK])
                
                if let event = channel?.creationEvent {
                    let tag = try EventTag(eventId: event.id)
                    
                    let builder = try? SetChannelMetadataEvent.Builder()
                        .channelMetadata(metadata)
                        .appendChannelCreateEventTag(tag)
                    
                    let event = try builder?.build(signedBy: account)
                    
                    NotificationCenter.default.post(
                        name: .updateChannelMetadata,
                        object: event
                    )
                }
            } catch {
                print("Error saving channel metadata: \(error)")
            }
        }
    }
}

#Preview {
    EditChannel(channel: Channel(name: "", about: "", picture: "", relays: [Constants.RELAY_URL_SKATEPARK], creationEvent: nil))
}
