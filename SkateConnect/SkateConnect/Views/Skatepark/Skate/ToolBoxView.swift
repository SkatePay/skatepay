//
//  ToolBoxView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/3/24.
//

import os

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
    let log = OSLog(subsystem: "SkateConnect", category: "ToolBox")
    
    @EnvironmentObject var debugManager: DebugManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var showingFilePicker = false
    @State private var selectedMediaURL: URL? = nil
    
    @State private var showingRequestPaymentPrompt = false
    @State private var amountToRequest: String = ""
    @State var selectedTokenKey: String?
    
    @State private var isUploading = false

    @State private var selectedAssetType: AssetType = .sol
    
    var channelId: String?
    var user: User?
    
    init(channelId: String? = nil, user: User? = nil) {
        self.channelId = channelId
        self.user = user
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
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.orange)
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
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.green)
                                Text("Request Crypto")
                                    .font(.caption)
                            }
                        }
                        .sheet(isPresented: $showingRequestPaymentPrompt) {
                            VStack(spacing: 20) {
                                Text("Request Crypto")
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
                                        
                                        Picker("Asset Type", selection: $selectedAssetType) {
                                            ForEach(AssetType.allCases, id: \.self) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .padding(.horizontal)
                                        
                                        if selectedAssetType == .token {
                                            // Token Picker
                                            let filteredTokens = walletManager.tokens.filter { $0.value.chainId == walletManager.network.chainId }
                                            
                                            
                                            if !filteredTokens.isEmpty {
                                                Section("Select Token") {
                                                    Picker("Token", selection: $selectedTokenKey) {
                                                        ForEach(filteredTokens.sorted(by: { $0.value.symbol < $1.value.symbol }), id: \.key) { token in
                                                            Text("\(token.value.symbol)").tag(token.key as String?)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        Text("Your wallet is not setup for this network.")
                                    }
                                }
                                TextField("Amount", text: $amountToRequest)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)
                                    .onChange(of: amountToRequest) {
                                        let filtered = amountToRequest.filter { "0123456789.".contains($0) }
                                        if filtered != amountToRequest {
                                            amountToRequest = filtered
                                        }
                                    }
                                
                                HStack {
                                    Button("Request") {
                                        handleInvoice()
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
                        .padding(10)
                    
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
                    .disabled(isUploading)
            }
            
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
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
    
    func handleInvoice() {
        Task {
            // 1. Determine Asset and Symbol
            let (asset, metadata, symbol) = await determineAssetAndSymbol()
            guard let asset = asset, let metadata = metadata, let symbol = symbol else { return }
            
            // 2. Get User Address
            let address = walletManager.getPublicKey() ?? "UNKNOWN"
            print("🧾 Requesting \(amountToRequest) \(symbol) from \(address) [Asset: \(asset)]")
            
            // 3. Create and Encrypt Invoice
            guard let invoiceString = createAndEncryptInvoice(asset: asset, metadata: metadata, address: address) else { return }
            
            // 4. Post Invoice to Channel (if available)
            if channelId != nil {
                postInvoiceToChannel(invoiceString: invoiceString)
            }
            
            if user != nil {
                postInvoiceToDM(invoiceString: invoiceString)
            }
            
            // 6. Dismiss Prompt
            showingRequestPaymentPrompt = false
        }
    }
    
    // MARK: - Helper Functions for handleInvoice
    
    private func determineAssetAndSymbol() async -> (asset: AssetType?, Metadata: String?, symbol: String?) {
        switch selectedAssetType {
        case .sol:
            return (.sol, "\(walletManager.network):SOL_NATIVE:SOL", "SOL")
            
        case .token:
            guard
                let tokenKey = selectedTokenKey,
                let token = walletManager.tokens[tokenKey]
            else {
                os_log("❌ No valid token selected", log: log, type: .error)
                showingRequestPaymentPrompt = false
                return (.token, nil, nil)
            }
            
            let metadataString: String?
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(token)
                metadataString = String(data: data, encoding: .utf8)
                if let metadataString = metadataString {
                    print("Encoded JSON: \(metadataString)")
                }
                
            } catch {
                os_log("❌ Failed to encode TokenMetadata:", log: log, type: .error)
                showingRequestPaymentPrompt = false
                return (.token, nil, nil)
            }
            
            return (.token, metadataString, token.symbol)
        }
    }
    
    private func createAndEncryptInvoice(asset: AssetType, metadata: String?, address: String) -> String? {
        let invoice = Invoice(
            asset: asset,
            metadata: metadata,
            amount: amountToRequest,
            address: address
        )
        
        guard let invoiceString = MessageHelper.encryptInvoiceToString(invoice: invoice) else {
            print("❌ Encryption failed for invoice")
            showingRequestPaymentPrompt = false
            return nil
        }
        return invoiceString
    }
    
    private func postInvoiceToChannel(invoiceString: String) {
        if let channelId = self.channelId {
            NotificationCenter.default.post(
                name: .publishChannelEvent,
                object: nil,
                userInfo: [
                    "channelId": channelId,
                    "content": "invoice:\(invoiceString)",
                    "kind": Kind.invoice
                ]
            )
            print("✅ Invoice posted to channel \(channelId)")
        }
    }
    
    private func postInvoiceToDM(invoiceString: String) {
        if let npub = self.user?.npub {
            NotificationCenter.default.post(
                name: .publishDMEvent,
                object: nil,
                userInfo: [
                    "npub": npub,
                    "content": "invoice:\(invoiceString)",
                    "kind": Kind.invoice
                ]
            )
            print("✅ Invoice posted to DM \(npub)")
        }
    }
    
    func hasWallet() -> Bool {
        return debugManager.hasEnabledDebug
    }
}

extension ToolBoxView {
    func postSelectedMedia(_ mediaURL: URL) async {
        os_log("⏳ Preparing to upload media: %@", log: log, type: .info, mediaURL.absoluteString)

        let currentChannelId = self.channelId
        let currentNpub = self.user?.npub

        guard currentChannelId != nil || currentNpub != nil else {
            os_log("🛑 Error: Neither channelId nor user npub is available. Cannot proceed with upload.", log: log, type: .error)
            // Consider updating UI state, e.g., self.isUploading = false
            return
        }

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
                os_log("⏳ Uploading image for channelId=[%@], npub=[%@]", log: log, type: .info, currentChannelId ?? "nil", currentNpub ?? "nil")
                try await uploadManager.uploadImage(
                    imageURL: mediaURL,
                    channelId: currentChannelId,
                    npub: currentNpub,
                    onLoadingStateChange: loadingStateHandler
                )
                
                os_log("✔️ Image upload successful: %@", log: log, type: .info, mediaURL.lastPathComponent)

                var userInfo: [String: Any] = [:]

                // Only add "npub" if currentNpub is not nil
                if let npub = currentNpub {
                    userInfo["npub"] = npub
                }

                // Only add "channelId" if currentChannelId is not nil
                if let channelId = currentChannelId {
                    userInfo["channelId"] = channelId
                }
                
                userInfo["source"] = SourceType.toolbox.rawValue

                navigation.completeUpload(imageURL: mediaURL, userInfo: userInfo)
            } else if fileType.conforms(to: .movie) {
                os_log("⏳ Uploading video for channelId=[%@], npub=[%@]", log: log, type: .info, currentChannelId ?? "nil", currentNpub ?? "nil")
                try await uploadManager.uploadVideo(
                    videoURL: mediaURL,
                    channelId: currentChannelId,
                    npub: currentNpub,
                    onLoadingStateChange: loadingStateHandler
                )
                os_log("✔️ Video upload successful: %@", log: log, type: .info, mediaURL.lastPathComponent)
                
                navigation.completeUpload(videoURL: mediaURL)

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
