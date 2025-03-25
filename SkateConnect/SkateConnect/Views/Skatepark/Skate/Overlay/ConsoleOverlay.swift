//
//  ConsoleOverlay.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI

struct ConsoleOverlay: View {
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var network: Network
    @EnvironmentObject private var stateManager: StateManager
    
    struct ConsoleMessage: Identifiable {
        let id = UUID()
        let attributedString: NSAttributedString
        let action: (() -> Void)?
    }
    
    @State private var messages: [ConsoleMessage] = []
    @State private var totalHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            if !messages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(messages) { message in
                        HStack(alignment: .top, spacing: 8) {
                            AttributedText(
                                attributedString: message.attributedString,
                                regularFont: UIFont.systemFont(ofSize: 12),
                                linkFont: UIFont.systemFont(ofSize: 12, weight: .bold)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture {
                                message.action?()
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeOut) {
                                    messages.removeAll { $0.id == message.id }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: SizePreferenceKey.self,
                                        value: proxy.size
                                    )
                            }
                        )
                    }
                }
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .frame(width: geometry.size.width * 0.92)
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    totalHeight = size.height * CGFloat(messages.count) + CGFloat(messages.count * 8) // account for spacing
                }
                .position(
                    x: geometry.size.width / 2,
                    y: stateManager.isShowingLoadingOverlay ?
                       min(72 + totalHeight/2, geometry.size.height/2) : // Below ticker
                       min(20 + totalHeight/2, geometry.size.height/2)    // Top of screen
                )
            }
        }
        .onAppear {
            setupInitialMessages()
        }
    }
    
    private func setupInitialMessages() {
        var initialMessages = [ConsoleMessage]()
        
        // Check if birthday is not set
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.birthday) as? Date == nil {
            initialMessages.append(
                createMessage(
                    text: "⚠️ Set your birthday (DOB).",
                    linkText: "birthday",
                    destination: .birthday
                )
            )
        }
        
        // Add other mandatory messages
        initialMessages.append(contentsOf: [
            createMessage(
                text: "⚠️ Mark your first spot.",
                linkText: "spot",
                destination: .createChannel
            )
        ])
        
        // Check if skatedeck is added
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.skatedeck) == nil {
            initialMessages.append(
                createMessage(
                    text: "⚠️ Add your board to deck tracker.",
                    linkText: "deck tracker",
                    destination: .deckTracker
                )
            )
        }
        
        messages = initialMessages
    }
    
    private func createMessage(text: String, linkText: String, destination: NavigationPathType) -> ConsoleMessage {
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.white
            ]
        )
        
        if let range = text.range(of: linkText) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemTeal,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.systemFont(ofSize: 12, weight: .bold)
            ], range: nsRange)
        }
        
        return ConsoleMessage(
            attributedString: attributedString,
            action: { navigation.path.append(destination) }
        )
    }
}

struct AttributedText: UIViewRepresentable {
    let attributedString: NSAttributedString
    let regularFont: UIFont
    let linkFont: UIFont
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        // Re-apply fonts in case they changed
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        mutableString.enumerateAttributes(in: NSRange(location: 0, length: mutableString.length)) { (attrs, range, _) in
            if attrs[.underlineStyle] == nil {
                mutableString.addAttribute(.font, value: regularFont, range: range)
            } else {
                mutableString.addAttribute(.font, value: linkFont, range: range)
            }
        }
        uiView.attributedText = mutableString
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
