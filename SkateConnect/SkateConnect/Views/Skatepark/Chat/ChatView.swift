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

// MARK: - MessageSwiftUIVC

final class MessageSwiftUIVC: MessagesViewController, MessageCellDelegate {
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (String) -> Void
    
    init(
        onTapAvatar: @escaping (String) -> Void,
        onTapVideo: @escaping (MessageType) -> Void,
        onTapLink: @escaping (String) -> Void
    ) {
        self.onTapAvatar = onTapAvatar
        self.onTapLink = onTapLink
        self.onTapVideo = onTapVideo
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        messagesCollectionView.scrollToLastItem(animated: true)
    }
    
    func didTapAvatar(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        let sender = message.sender
        onTapAvatar(sender.senderId)
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        if case MessageKind.linkPreview(let linkItem) = message.kind {
            let pathComponents = linkItem.url.pathComponents
            
            if let channelId = pathComponents.last {
                onTapLink(channelId)
            } else {
                print("Failed to extract channel ID")
            }
        } else {
            print("Message tapped")
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        onTapVideo(message)
    }
}

// MARK: - MessagesView

struct ChatAreaView: View {
    @Binding var messages: [MessageType]

    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (String) -> Void
    let onSend: (String) -> Void
    
    var body: some View {
        ChatView(
            messages: $messages,
            onTapAvatar: onTapAvatar,
            onTapVideo: onTapVideo,
            onTapLink: onTapLink,
            onSend: onSend
        )
    }
}

struct ChatView: UIViewControllerRepresentable {
    @State var initialized = false
    
    @Binding var messages: [MessageType]
    
    let keychainForNostr = NostrKeychainStorage()
    
    func getCurrentUser() -> MockUser {
        guard let account = keychainForNostr.account else { return MockUser(senderId: "000002", displayName: "You") }
        return MockUser(senderId: account.publicKey.npub, displayName: "You")
    }
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    let onTapLink: (String) -> Void
    let onSend: (String) -> Void
    
    func makeUIViewController(context: Context) -> MessagesViewController {
        let messagesVC = MessageSwiftUIVC(onTapAvatar: onTapAvatar, onTapVideo: onTapVideo, onTapLink: onTapLink)
        
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messagesCollectionView.messageCellDelegate = messagesVC
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.messageInputBar.inputTextView.autocorrectionType = .no
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = false // default false
        messagesVC.maintainPositionOnInputBarHeightChanged = false // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        
        context.coordinator.updateFirstMessagesOfDay(messages)

        return messagesVC
    }
    
    func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onSend: onSend)
    }
    
    // MARK: Private
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.initialized)
            self.initialized = true
        }
    }
    
    final class Coordinator: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate {
        var parent: ChatView
        let onSend: (String) -> Void
        
        var supportUser: User?
        var currenUser: MockUser?
        
        private var firstMessagesOfDay: [IndexPath: Date] = [:]

        init(_ parent: ChatView, onSend: @escaping (String) -> Void) {
            self.parent = parent
            self.onSend = onSend
            self.supportUser = AppData().getSupport()
            self.currenUser = parent.getCurrentUser()
        }
        
        // MARK: - Update First Messages of the Day
        
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
        
        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
        
        func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
            onSend(text)
            inputBar.inputTextView.text = ""
        }
        
        var currentSender: SenderType {
            currenUser!
        }
        
        func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
            return parent.messages[indexPath.section]
        }
        
        func numberOfSections(in _: MessagesCollectionView) -> Int {
            return parent.messages.count
        }
        
        func photoCell(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView)
        -> UICollectionViewCell? {
            return nil
        }
        
        func textCell(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UICollectionViewCell? {
            nil
        }
        
        // MARK: - MessagesLayoutDelegate
        
        func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
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
        
        
        func messageTopLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
            var name = message.sender.displayName
            
            if (message.sender.senderId == self.supportUser?.npub) {
                name = AppData().getSupport().name
            }
            
            return NSAttributedString(
                string: name,
                attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
        }
        
        func messageBottomLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
            return nil
        }
        
        func messageTimestampLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
            let sentDate = message.sentDate
            let sentDateString = MessageKitDateFormatter.shared.string(from: sentDate)
            let timeLabelFont: UIFont = .boldSystemFont(ofSize: 10)
            let timeLabelColor: UIColor = .systemGray
            return NSAttributedString(
                string: sentDateString,
                attributes: [NSAttributedString.Key.font: timeLabelFont, NSAttributedString.Key.foregroundColor: timeLabelColor])
        }
        
        func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) {
            if (message.sender.senderId == self.supportUser?.npub) {
                if let supportImageName = self.supportUser?.imageName {
                    let avatar = Avatar(image: UIImage(named: supportImageName), initials: "SC")
                    avatarView.set(avatar: avatar)
                }
            } else {
                let avatar = SampleData.shared.getAvatarFor(sender: message.sender)
                avatarView.set(avatar: avatar)
            }
        }
        
        func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView)
        -> UIColor {
            if case MessageKind.linkPreview(_) = message.kind {
                return UIColor.systemIndigo
            }
            
            if (message.sender.senderId == self.supportUser?.npub) {
                return UIColor.systemOrange
            } else if (message.sender.senderId == currenUser?.senderId) {
                return UIColor.systemBlue
            } else {
                return UIColor.darkGray
            }
        }
        
       func messageTopLabelHeight(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
            return 16
        }
        
        func messageBottomLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
            0
        }
        
        @MainActor
        func configureMediaMessageImageView(
            _ imageView: UIImageView,
            for message: MessageType,
            at _: IndexPath,
            in _: MessagesCollectionView)
        {
            if case MessageKind.photo(let media) = message.kind, let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            } else if case MessageKind.video(let media) = message.kind, let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            }
            else {
                imageView.kf.cancelDownloadTask()
            }
        }
    }
    
    
    
}
