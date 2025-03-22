//
//  RecoveryPhraseView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/21/25.
//

import SwiftUI
import NostrSDK
import SolanaSwift

// MARK: - Recovery Phrase Full-Screen
struct RecoveryPhraseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager

    let mnemonic: [String]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Recovery Phrase")
                .font(.title)
                .padding(.top, 40)
            
            Text("Keep your recovery phrase secret. Anyone with it can access your funds.")
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Display the mnemonic in a grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                    ForEach(Array(mnemonic.enumerated()), id: \.offset) { index, word in
                        HStack {
                            Text("\(index + 1). \(word)")
                                .font(.callout)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
            
            HStack(spacing: 40) {
                // Copy button
                Button {
                    let phraseString = mnemonic.joined(separator: " ")
                    UIPasteboard.general.string = phraseString
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                
                // Done button
                Button("Done") {
                    walletManager.refreshAliases()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
}
