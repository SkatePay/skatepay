//
//  MessageView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/14/24.
//

import InputBarAccessoryView
import Kingfisher
import MessageKit
import NostrSDK
import SwiftUI
import UIKit

enum ChatAction: String {
    case invoice
    case invite
    case unknown
}

final class MessageSwiftUIVC: MessagesViewController {
    
    // MARK: - Properties
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (ChatAction, String, String) -> Void
    
    var firstTime = false
    
    // MARK: - Initializers
    
    init(
        onTapAvatar: @escaping (String) -> Void,
        onTapVideo: @escaping (MessageType) -> Void,
        onTapLink: @escaping (ChatAction, String, String) -> Void
    ) {
        self.onTapAvatar = onTapAvatar
        self.onTapVideo = onTapVideo
        self.onTapLink = onTapLink
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        
        if (!firstTime) {
            messagesCollectionView.scrollToLastItem(animated: true)
            firstTime = true
        }
    }
}

struct ChatView: UIViewControllerRepresentable {
    var currentUser: MockUser = MockUser(senderId: "000002", displayName: "You")
    
    @Binding var messages: [MessageType]
    @Binding var shouldScrollToBottom: Bool
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (ChatAction, String, String) -> Void
    let onSend: (String) -> Void
    
    func makeUIViewController(context: Context) -> MessagesViewController {
        let messagesVC = MessageSwiftUIVC(
            onTapAvatar: onTapAvatar,
            onTapVideo: onTapVideo,
            onTapLink: onTapLink
        )
        
        // Set delegates for MessageKit
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messagesCollectionView.messageCellDelegate = context.coordinator
        
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.messageInputBar.inputTextView.autocorrectionType = .no
        
        // Configure scrolling behavior
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true
        messagesVC.maintainPositionOnInputBarHeightChanged = false
        messagesVC.showMessageTimestampOnSwipeLeft = true
        
        context.coordinator.updateFirstMessagesOfDay(messages)
        
        context.coordinator.messagesViewController = messagesVC
        
        return messagesVC
    }
    
    func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        uiViewController.messagesCollectionView.reloadData()
        
        if (shouldScrollToBottom) {
            scrollToBottom(uiViewController)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onSend: { text in
            shouldScrollToBottom = true
            onSend(text)
        })
    }
    
    // MARK: - Private Methods
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.shouldScrollToBottom)
            self.shouldScrollToBottom = false
        }
    }
    
    // MARK: - Coordinator
    
    final class Coordinator: NSObject, MessagesDataSource, MessagesLayoutDelegate, InputBarAccessoryViewDelegate {
        
        // MARK: - Properties
        
        var parent: ChatView
        let onSend: (String) -> Void
        var supportUser: User?
        
        private var firstMessagesOfDay: [IndexPath: Date] = [:]
        
        // Add this property to store the MessagesViewController
        weak var messagesViewController: MessagesViewController?
        
        // MARK: - Initializer
        
        init(_ parent: ChatView, onSend: @escaping (String) -> Void) {
            self.parent = parent
            self.onSend = onSend
            self.supportUser = AppData().getSupport()
        }
        
        // MARK: - First Messages of Day
        
        func updateFirstMessagesOfDay(_ messages: [MessageType]) {
            firstMessagesOfDay.removeAll()
            var lastDate: Date?
            
            for (index, message) in messages.enumerated() {
                let messageDate = Calendar.current.startOfDay(for: message.sentDate)
                if lastDate == nil || lastDate != messageDate {
                    let indexPath = IndexPath(item: 0, section: index)
                    firstMessagesOfDay[indexPath] = messageDate
                }
                lastDate = messageDate
            }
        }
        
        // MARK: - Date Formatter
        
        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
        
        // MARK: - InputBarAccessoryViewDelegate
        
        func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
            onSend(text)
            inputBar.inputTextView.text = ""
        }
        
        // MARK: - MessagesDataSource
        
        var currentSender: SenderType {
            parent.currentUser
        }
        
        func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
            let message = parent.messages[indexPath.section]
            return message
        }
        
        func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
            return parent.messages.count
        }
        
        // Optional methods that are not used
        func photoCell(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UICollectionViewCell? { nil }
        func textCell(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UICollectionViewCell? { nil }
        
        // MARK: - MessagesLayoutDelegate
        
        func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            return firstMessagesOfDay.keys.contains(indexPath) ? 30 : 0
        }
        
        func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            if let messageDate = firstMessagesOfDay[indexPath] {
                return NSAttributedString(
                    string: MessageKitDateFormatter.shared.string(from: messageDate),
                    attributes: [
                        .font: UIFont.boldSystemFont(ofSize: 12),
                        .foregroundColor: UIColor.gray
                    ]
                )
            }
            return nil
        }
        
        func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            var name = message.sender.displayName
            if message.sender.senderId == supportUser?.npub {
                name = AppData().getSupport().name
            }
            return NSAttributedString(
                string: name,
                attributes: [.font: UIFont.preferredFont(forTextStyle: .caption1)]
            )
        }
        
        func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            return nil
        }
        
        func messageTimestampLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
            let sentDateString = MessageKitDateFormatter.shared.string(from: message.sentDate)
            return NSAttributedString(
                string: sentDateString,
                attributes: [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.systemGray
                ]
            )
        }
        
        // MARK: - Message Appearance
        
        func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            return 16
        }
        
        func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
            return 0
        }
    }
}

extension ChatView.Coordinator: MessagesDisplayDelegate {
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        if message.sender.senderId == supportUser?.npub,
           let supportImageName = supportUser?.imageName {
            let avatar = Avatar(image: UIImage(named: supportImageName), initials: "SC")
            avatarView.set(avatar: avatar)
        } else {
            let avatar = SampleData.shared.getAvatarFor(sender: message.sender)
            avatarView.set(avatar: avatar)
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        if case .linkPreview(_) = message.kind {
            return UIColor.systemIndigo
        }
        
        if message.sender.senderId == supportUser?.npub {
            return UIColor.systemOrange
        } else if message.sender.senderId == parent.currentUser.senderId {
            return UIColor.systemBlue
        } else {
            return UIColor.darkGray
        }
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        return [
            .foregroundColor: UIColor.label,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.label
        ]
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        if case .attributedText(_) = message.kind {
            return [.url]
        }
        return []
    }
    
    // MARK: - Media Configuration
    
    @MainActor
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        switch message.kind {
        case .photo(let media):
            if let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            }
        case .video(let media):
            if let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            }
        default:
            imageView.kf.cancelDownloadTask()
        }
    }
}

extension ChatView.Coordinator: MessageCellDelegate {
    func didTapAvatar(in cell: MessageCollectionViewCell) {
        guard
            let indexPath = messagesViewController?.messagesCollectionView.indexPath(for: cell),
            let dataSource = messagesViewController?.messagesCollectionView.messagesDataSource
        else { return }
        
        let message = dataSource.messageForItem(at: indexPath, in: messagesViewController!.messagesCollectionView)
        parent.onTapAvatar(message.sender.senderId)
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard
            let indexPath = messagesViewController?.messagesCollectionView.indexPath(for: cell),
            let dataSource = messagesViewController?.messagesCollectionView.messagesDataSource
        else { return }
        
        let message = dataSource.messageForItem(at: indexPath, in: messagesViewController!.messagesCollectionView)
        
        switch message.kind {
        case .linkPreview(let linkItem):
            let url = linkItem.url
            print("🔗 URL: \(url)")
            
            // Extract channelId from last path component
            let channelId = url.pathComponents.last ?? ""
            
            // Extract action query param
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let actionString = components?.queryItems?.first(where: { $0.name == "action" })?.value ?? ""
            let action = ChatAction(rawValue: actionString) ?? .unknown
                        
            print("🆔 Channel ID: \(channelId)")
            print("🎬 Action: \(action)")
            
            if !channelId.isEmpty, let attributedText = linkItem.attributedText {
                parent.onTapLink(action, channelId, attributedText.string)
            } else {
                print("❌ Failed to extract channel ID or attributed text")
            }
        default:
            print("Tapped message with no link preview.")
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard
            let indexPath = messagesViewController?.messagesCollectionView.indexPath(for: cell),
            let dataSource = messagesViewController?.messagesCollectionView.messagesDataSource
        else { return }
        
        let message = dataSource.messageForItem(at: indexPath, in: messagesViewController!.messagesCollectionView)
        parent.onTapVideo(message)
    }
}

extension ChatView.Coordinator: MessageLabelDelegate {
    func didSelectURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
