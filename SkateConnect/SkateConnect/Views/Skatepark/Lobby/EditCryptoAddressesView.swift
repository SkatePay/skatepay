//
//  EditCryptoAddressesView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 1/29/25.
//

import SwiftUI
import SwiftData

struct EditCryptoAddressesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Binding var friend: Friend? // Accept optional Binding<Friend?>

    @State private var newAddress: String = ""
    @State private var newNetwork: String = "testnet"
    @State private var isAddressValid: Bool = true
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            if let friend = friend {
                Form {
                    addNewAddressSection(friend: friend)
                    existingAddressesSection(friend: friend)
                }
                .navigationTitle("Edit Crypto Addresses")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                Text("No friend selected")
                    .padding()
            }
        }
    }
}

// MARK: - Subviews
private extension EditCryptoAddressesView {
    // MARK: - Subviews
    private func addNewAddressSection(friend: Friend) -> some View {
        Section(header: Text("Add New Solana Address")) {
            TextField("Solana Address", text: $newAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .onChange(of: newAddress) {
                    validateAddress()
                }
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)

            Picker("Network", selection: $newNetwork) {
                Text("Testnet").tag("testnet")
                Text("Mainnet").tag("mainnet")
            }
            .pickerStyle(SegmentedPickerStyle())

            if !isAddressValid {
                Text("⚠️ Invalid Solana address")
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button("Add Address") {
                addAddress(to: friend)
            }
            .disabled(newAddress.isEmpty || !isAddressValid) // Disable if invalid
        }
    }

    private func existingAddressesSection(friend: Friend) -> some View {
        Section(header: Text("Existing Addresses")) {
            if friend.cryptoAddresses.isEmpty {
                Text("No saved addresses.")
                    .foregroundColor(.gray)
            } else {
                ForEach(friend.cryptoAddresses) { address in
                    VStack(alignment: .leading) {
                        Text(address.address)
                            .font(.headline)
                            .textSelection(.enabled)

                        Text(address.network.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: { offsets in
                    deleteAddress(from: friend, at: offsets)
                })
            }
        }
    }

    // MARK: - Methods
    private func addAddress(to friend: Friend) {
        guard isAddressValid else { return }

        let cryptoAddress = CryptoAddress(address: newAddress, blockchain: "solana", network: newNetwork)
        friend.cryptoAddresses.append(cryptoAddress)

        try? context.save() // Persist changes

        newAddress = ""
        isAddressValid = true
    }

    private func deleteAddress(from friend: Friend, at offsets: IndexSet) {
        for index in offsets {
            friend.cryptoAddresses.remove(at: index)
        }
        try? context.save()
    }

    private func validateAddress() {
        let allowedCharacters = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        
        // Only validate when the input is non-empty
        if newAddress.isEmpty {
            isAddressValid = true // Reset validation when empty
        } else {
            isAddressValid = (newAddress.count >= 32 && newAddress.count <= 44) &&
                             newAddress.rangeOfCharacter(from: allowedCharacters.inverted) == nil
        }
    }
}
