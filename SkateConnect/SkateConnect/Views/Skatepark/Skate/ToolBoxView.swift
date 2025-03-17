//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import CryptoKit
import SwiftUI
import SolanaSwift
import UniformTypeIdentifiers

extension SolanaSwift.Network {
    var chainId: Int {
        switch self {
        case .mainnetBeta: return 101
        case .testnet, .devnet: return 102
        }
    }
}

struct ToolBoxView: View {
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var showingFilePicker = false
    @State private var selectedMediaURL: URL? = nil
    
    @State private var showingRequestPaymentPrompt = false
    @State private var amountToRequest: String = ""
    @State var selectedTokenKey: String?
    
    private var channelId: String {
        navigation.channelId ?? ""
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
                    
                    if hasWallet() {
                        Button(action: {
                            showingRequestPaymentPrompt = true
                        }) {
                            VStack {
                                Image(systemName: "creditcard")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.green)
                                Text("Request Payment")
                                    .font(.caption)
                            }
                        }
                        .sheet(isPresented: $showingRequestPaymentPrompt) {
                            VStack(spacing: 20) {
                                Text("Request Payment")
                                    .font(.headline)

                                List {
                                    // Network Picker
                                    Section("Network") {
                                        Picker("Network", selection: $walletManager.network) {
                                            Text("Mainnet").tag(SolanaSwift.Network.mainnetBeta)
                                            Text("Testnet").tag(SolanaSwift.Network.testnet)
                                        }
                                        .onChange(of: walletManager.network) {
                                            walletManager.refreshAliases()
                                        }
                                    }
                                    
                                    // Alias Picker
                                    if (!walletManager.getAliasesForCurrentNetwork().isEmpty) {
                                        Section("Select Account") {
                                            Picker("Alias", selection: $walletManager.selectedAlias) {
                                                ForEach(walletManager.aliases, id: \.self) { alias in
                                                    Text(alias).tag(alias)
                                                }
                                            }
                                            .onChange(of: walletManager.selectedAlias) {
                                                walletManager.refreshAliases()
                                            }
                                        }
                                        // Token Picker
                                        let filteredTokens = walletManager.tokens.filter { $0.value.chainId == walletManager.network.chainId }

                                        
                                        if !filteredTokens.isEmpty {
                                            Section("Select Token") {
                                                Picker("Token", selection: $selectedTokenKey) {
                                                    ForEach(filteredTokens.sorted(by: { $0.value.symbol < $1.value.symbol }), id: \.key) { token in
                                                        Text(token.value.symbol).tag(token.key as String?)
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        Text("You don't have any aliases set up for this network.")
                                    }
                                }
                                TextField("Amount", text: $amountToRequest)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)

                                HStack {
                                    Button("Request") {
                                        guard
                                            let tokenKey = selectedTokenKey,
                                            let token = walletManager.tokens[tokenKey]
                                        else {
                                            print("❌ No valid token selected")
                                            showingRequestPaymentPrompt = false
                                            return
                                        }

                                        let asset = "\(walletManager.network):\(token.mintAddress):\(token.symbol)"
                                        let address = walletManager.getPublicKey() ?? "UNKNOWN"

                                        print("🧾 Requesting \(amountToRequest) \(token.symbol) from \(address) [Asset: \(asset)]")

                                        let invoice = Invoice(
                                            asset: asset,
                                            amount: amountToRequest,
                                            address: address
                                        )

                                        guard let invoiceString = MessageHelper.encryptInvoiceToString(invoice: invoice) else {
                                            print("❌ Encryption failed for invoice")
                                            showingRequestPaymentPrompt = false
                                            return
                                        }

                                        NotificationCenter.default.post(
                                            name: .publishChannelEvent,
                                            object: nil,  // You can use `nil` here safely
                                            userInfo: [
                                                "channelId": channelId,
                                                "content": "invoice:\(invoiceString)",
                                                "kind": Kind.invoice
                                            ]
                                        )

                                        print("✅ Invoice posted to channel \(channelId)")
                                        showingRequestPaymentPrompt = false
                                    }
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)

                                    Button("Cancel") {
                                        showingRequestPaymentPrompt = false
                                    }
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
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
        .onAppear {
            let filteredTokens = walletManager.tokens.filter { $0.value.chainId == walletManager.network.chainId }
            if selectedTokenKey == nil, let firstKey = filteredTokens.first?.key {
                selectedTokenKey = firstKey
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
    
    /// Checks if the user has a wallet
    func hasWallet() -> Bool {
        return debugManager.hasEnabledDebug
    }
}

#Preview {
    ToolBoxView()
}
