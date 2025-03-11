//
//  EULAView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/15/24.
//

import ConnectFramework
import NostrSDK
import SwiftUI

struct CheckboxWithLabel: View {
    @Binding var isOn: Bool
    let label: String
    
    var body: some View {
        HStack {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(isOn ? .blue : .gray)
                .onTapGesture {
                    isOn.toggle()
                }
            Text(label)
        }
        .onTapGesture {
            isOn.toggle()
        }
    }
}


// Placeholder for EULA content
var eulaText: String {
    """
    SkateConnect App End User License Agreement (EULA)
    
    Welcome to SkateConnect! By downloading, installing, or using the SkateConnect app ("App"), you agree to be bound by the terms and conditions of this End User License Agreement ("EULA"). If you do not agree to these terms, please do not install or use the App.
    
    1. License Grant
    
    SkateConnect grants you a revocable, non-exclusive, non-transferable, limited license to install and use the App solely for your personal, non-commercial purposes on any mobile device that you own or control, subject to the terms and conditions of this EULA.
    
    2. User Conduct
    
    Content Standards: You agree not to upload, post, or transmit any content that:
    Is unlawful, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, libelous, invasive of another's privacy, or racially, ethnically, or otherwise objectionable.
    Infringes any patent, trademark, trade secret, copyright, or other proprietary rights of any party.
    Contains software viruses or any other computer code, files, or programs designed to interrupt, destroy, or limit the functionality of any computer software or hardware or telecommunications equipment.
    Prohibited Conduct: You must not:
    Use the App in any manner that could disable, overburden, damage, or impair the site or interfere with any other party's use and enjoyment of the App.
    Attempt to gain unauthorized access to the App, other accounts, computer systems, or networks connected to the App through hacking, password mining, or any other means.
    Engage in any conduct that restricts or inhibits anyone's use or enjoyment of the App, or which, as determined by us, may harm SkateConnect or users of the App or expose them to liability.
    
    3. Intellectual Property Rights
    
    The App and all its components, including but not limited to text, graphics, logos, button icons, images, audio clips, digital downloads, data compilations, and software, are the property of SkateConnect or its content suppliers and are protected by international copyright laws. The App is provided for your personal use only and may not be used for any commercial purpose.
    
    4. Termination
    
    SkateConnect reserves the right to terminate or suspend your access to the App at any time, without notice, for any reason, including, without limitation, if SkateConnect believes that you have violated or acted inconsistently with the letter or spirit of this EULA. Upon termination, you must immediately destroy any downloaded or printed App.
    
    5. Disclaimer of Warranties
    
    The App is provided "as is" without warranty of any kind, either express or implied, including, but not limited to, the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.
    
    6. Limitation of Liability
    
    In no event will SkateConnect be liable for any damages, including without limitation direct or indirect, special, incidental, or consequential damages, losses or expenses arising out of or in connection with this EULA or use of or inability to use the App.
    
    7. Indemnification
    
    You agree to indemnify and hold SkateConnect, its subsidiaries, affiliates, officers, agents, and other partners and employees, harmless from any claim or demand, including reasonable attorneys' fees, made by any third party due to or arising out of your breach of this EULA, or your violation of any law or the rights of a third party.
    
    8. Governing Law
    
    This EULA shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law principles.
    
    9. Changes to this EULA
    
    SkateConnect reserves the right to modify this EULA at any time. Your continued use of the App after any such changes constitutes your acceptance of the new EULA.
    
    10. Contact Information
    
    If you have any questions about this EULA, please contact us at support@skatepark.chat.
    
    By clicking "I Agree" or by using the SkateConnect App, you acknowledge that you have read, understood, and agree to be bound by this EULA. If you do not agree to this EULA, do not use the App.
    """
}

struct EULAView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var eulaManager: EULAManager
        
    @State private var agreeToTerms = false    

    var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown Version"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("🌐 SkateConnect \(appVersion) 🛹")
                    .font(.title)
                    .bold()
                
                Image("user-skateconnect") // Replace with your image name
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                
                // EULA Content
                ScrollView {
                    Text(eulaText)
                        .font(.body)
                        .padding()
                }
                .frame(height: 300) // Adjust height as needed
                
                // Agreement Toggle
                CheckboxWithLabel(isOn: $agreeToTerms, label: "I agree to the terms and conditions")
                    .padding()
                
                // Action Button
                Button(action: {
                    if agreeToTerms {
                        eulaManager.acknowledgeEULA()
                        
                        NotificationCenter.default.post(name: .startNetwork, object: nil)
                        
                        dismiss()
                    } else {
                        print("User must agree to EULA to proceed")
                        
                    }
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreeToTerms ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!agreeToTerms)
                
                Button("Visit Website") {
                    Task {
                        if let url = URL(string: ProRobot.HELP_URL_SKATECONNECT) {
                            openURL(url)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
    }
}

// Custom Toggle Style to look like a checkbox
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
            .foregroundColor(configuration.isOn ? .blue : .gray)
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}

// Preview

#Preview {
    EULAView()
}
