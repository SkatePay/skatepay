//
//  EditCryptoAddressesView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import SolanaSwift
import SwiftUI

struct EditCryptoAddressesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var friend: Friend

    @State private var newAddress: String = ""
    @State private var newNetwork: String = "testnet"
    @State private var isAddressValid: Bool = true
    @State private var cryptoAddresses: [CryptoAddress] = []

    var body: some View {
        Form {
            addNewAddressSection
            existingAddressesSection
        }
        .navigationTitle("Edit Crypto Addresses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            cryptoAddresses = friend.cryptoAddresses // Ensure UI updates
        }
    }
}

// MARK: - Subviews
private extension EditCryptoAddressesView {
    var addNewAddressSection: some View {
        Section(header: Text("Add New Solana Address")) {
            TextField("Solana Address", text: $newAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
            
            Picker("Network", selection: $newNetwork) {
                Text("Testnet").tag(SolanaSwift.Network.testnet.stringValue)
                Text("Mainnet").tag(SolanaSwift.Network.mainnetBeta.stringValue)
            }
            .pickerStyle(SegmentedPickerStyle())

            if !isAddressValid {
                Text("⚠️ Invalid Solana address")
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button("Add Address") {
                addAddress()
            }
            .disabled(newAddress.isEmpty || !isAddressValid)
        }
    }

    var existingAddressesSection: some View {
        Section(header: Text("Existing Addresses")) {
            if cryptoAddresses.isEmpty {
                Text("No saved addresses.")
                    .foregroundColor(.gray)
            } else {
                ForEach(cryptoAddresses) { address in
                    VStack(alignment: .leading) {
                        Text(address.address)
                            .font(.headline)
                            .textSelection(.enabled)

                        Text(address.network.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete { indices in
                    deleteAddress(at: indices)
                }
            }
        }
    }
}

// MARK: - Methods
private extension EditCryptoAddressesView {
    func addAddress() {
        validateAddress()
        
        guard isAddressValid else { return }
        let cryptoAddress = CryptoAddress(address: newAddress, blockchain: "solana", network: newNetwork)

        cryptoAddresses.append(cryptoAddress)
        friend.cryptoAddresses = cryptoAddresses

        context.insert(friend)
        try? context.save()

        newAddress = ""
        isAddressValid = true
    }

    func deleteAddress(at offsets: IndexSet) {
        cryptoAddresses.remove(atOffsets: offsets)
        friend.cryptoAddresses = cryptoAddresses

        context.insert(friend)
        try? context.save()
    }

    func validateAddress() {
        isAddressValid = newAddress.count >= 32 && newAddress.count <= 44
    }
}
