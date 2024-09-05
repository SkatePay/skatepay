//
//  WalletHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK

struct WalletHome: View {
    @Binding var host: Host
    
    @State private var privateKey: String?
    @State private var publicKey: String?
    @State private var nsec: String?
    @State private var npub: String?
    
    let saveAction: ()->Void

    @Environment(\.scenePhase) private var scenePhase
    
    private let noValueString = ""

    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Button("🔁 Cycle Keys") {
                let keypair = Keypair()
                privateKey = keypair?.privateKey.hex ?? noValueString
                publicKey = keypair?.publicKey.hex ?? noValueString
                
                nsec = keypair?.privateKey.nsec ?? ""
                npub = keypair?.publicKey.npub ?? ""
                
                host.privateKey = keypair?.privateKey.hex ?? noValueString
                host.publicKey = keypair?.publicKey.hex ?? noValueString
                
                host.nsec = keypair?.privateKey.nsec ?? ""
                host.npub = keypair?.publicKey.npub ?? ""
                
                saveAction()
            }
            Section("npub") {
                Text(npub ?? host.npub)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = npub ?? host.npub
                        }) {
                            Text("Copy")
                            }
                        
                        Button(action: {
                            UIPasteboard.general.string = publicKey ?? host.publicKey
                        }) {
                            Text("Copy Hex")
                            }
                        }
            }
            
            Section("nsec") {
                Text(nsec ?? host.nsec)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = nsec ?? host.nsec
                        }) {
                            Text("Copy")
                            }
                        
                        Button(action: {
                            UIPasteboard.general.string = privateKey ?? host.privateKey
                        }) {
                            Text("Copy Hex")
                            }
                        }
            }
            
            Button {
                if let url = URL(string: "https://prorobot.ai/en/articles/prorobot-the-robot-friendly-blockchain-pioneering-the-future-of-robotics") {
                    openURL(url)
                }
            } label: {
                Label("Get Help", systemImage: "person.fill.questionmark")
            }
        }
    }
}

#Preview {
    WalletHome(host: .constant(Host()), saveAction: {})
}
