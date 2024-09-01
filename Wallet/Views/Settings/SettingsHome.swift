//
//  SettingsHome.swift
//  Wallet
//
//  Created by Konstantin Yurchenko, Jr on 8/30/24.
//

import SwiftUI
import NostrSDK

struct SettingsHome: View {
    @Binding var host: Host
    
    @State private var privateKey: String?
    @State private var publicKey: String?
    @State private var nsec: String?
    @State private var npub: String?
    
    let saveAction: ()->Void

    @Environment(\.scenePhase) private var scenePhase
    
    private let noValueString = "Must generate key"

    var body: some View {
        Form {
            Button("Generate Key") {
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
            Section("Private Key") {
                Text(privateKey ?? host.privateKey)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = privateKey ?? host.privateKey
                        }) {
                            Text("Copy")
                            }
                        }
            }
            Section("Public Key") {
                Text(publicKey ?? host.publicKey)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = publicKey ?? host.publicKey
                        }) {
                            Text("Copy")
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
                        }
            }
            Section("npub") {
                Text(npub ?? host.npub)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = npub ?? host.npub
                        }) {
                            Text("Copy")
                            }
                        }
            }
        }
    }
}

#Preview {
    SettingsHome(host: .constant(Host()), saveAction: {})
}
