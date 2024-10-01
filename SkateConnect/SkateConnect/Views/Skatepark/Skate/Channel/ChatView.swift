//
//  MessageView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/14/24.
//

import InputBarAccessoryView
import Kingfisher
import MessageKit
import SwiftUI
import UIKit

// MARK: - MessageSwiftUIVC

final class MessageSwiftUIVC: MessagesViewController, MessageCellDelegate {
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    
    init(onTapAvatar: @escaping (String) -> Void, onTapVideo: @escaping (MessageType) -> Void) {
        self.onTapAvatar = onTapAvatar
        self.onTapVideo = onTapVideo
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Because SwiftUI wont automatically make our controller the first responder, we need to do it on viewDidAppear
        becomeFirstResponder()
        messagesCollectionView.scrollToLastItem(animated: true)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("User started editing the text field.")
        // You can perform any actions here when the cursor enters the text field
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("User finished editing the text field.")
        // You can perform any actions here when the cursor leaves the text field
    }
    
    func didTapAvatar(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        let sender = message.sender
        onTapAvatar(sender.senderId)
    }
    
    func didTapMessage(in _: MessageCollectionViewCell) {
        print("Message tapped")
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        guard let messagesDataSource = messagesCollectionView.messagesDataSource else { return }
        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        
        onTapVideo(message)
    }
}

// MARK: - MessagesView

struct ChatView: UIViewControllerRepresentable {
    // MARK: Internal
    
    
    final class Coordinator: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate {
        // MARK: Lifecycle
        
        let keychainForNostr = NostrKeychainStorage()
        
        @ObservedObject var feedDelegate = FeedDelegate.shared
        
        var currentUser = MockUser(senderId: "000002", displayName: "You")
        
        init(messages: Binding<[MessageType]>) {
            self.messages = messages
            
            let keychainForNostr = NostrKeychainStorage()
            
            guard let account = keychainForNostr.account else { return }
            currentUser.senderId = account.publicKey.npub
        }
        
        // MARK: Internal
        
        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
        
        var messages: Binding<[MessageType]>
        
        func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
            feedDelegate.publishDraft(text: text)
            inputBar.inputTextView.text = ""
        }
        
        var currentSender: SenderType {
            currentUser
        }
        
        func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
            messages.wrappedValue[indexPath.section]
        }
        
        func numberOfSections(in _: MessagesCollectionView) -> Int {
            messages.wrappedValue.count
        }
        
        func photoCell(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView)
        -> UICollectionViewCell? {
            return nil
        }
        
        func messageTopLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
            var name = message.sender.displayName

            if (message.sender.senderId == AppData().getSupport().npub) {
                name = AppData().getSupport().name
            }

            return NSAttributedString(
                string: name,
                attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
        }
        
        //        func messageBottomLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
        //            let dateString = formatter.string(from: message.sentDate)
        //            return NSAttributedString(
        //                string: dateString,
        //                attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
        //        }
        
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
            if (message.sender.senderId == AppData().getSupport().npub) {
                let supportImageName = AppData().getSupport().imageName
                let avatar = Avatar(image: UIImage(named: supportImageName), initials: "SC")
                avatarView.set(avatar: avatar)
            } else {
                let avatar = SampleData.shared.getAvatarFor(sender: message.sender)
                avatarView.set(avatar: avatar)
            }
        }
        
        func messageTopLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
            16
        }
        
        func messageBottomLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
            0
        }
        
        func configureMediaMessageImageView(
            _ imageView: UIImageView,
            for message: MessageType,
            at _: IndexPath,
            in _: MessagesCollectionView)
        {
            if case MessageKind.photo(let media) = message.kind, let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            }
            if case MessageKind.video(let media) = message.kind, let imageURL = media.url {
                imageView.kf.setImage(with: imageURL)
            }
            else {
                imageView.kf.cancelDownloadTask()
            }
        }
        
    }
    
    @State var initialized = false
    @Binding var messages: [MessageType]
    
    let onTapAvatar: (String) -> Void
    let onTapVideo: (MessageType) -> Void
    
    func makeUIViewController(context: Context) -> MessagesViewController {
        let messagesVC = MessageSwiftUIVC(onTapAvatar: onTapAvatar, onTapVideo: onTapVideo)
        
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messagesCollectionView.messageCellDelegate = messagesVC
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.messageInputBar.inputTextView.autocorrectionType = .no
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = false // default false
        messagesVC.maintainPositionOnInputBarHeightChanged = true // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        
        return messagesVC
    }
    
    func updateUIViewController(_ uiViewController: MessagesViewController, context _: Context) {
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(messages: $messages)
    }
    
    // MARK: Private
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.initialized)
            self.initialized = true
        }
    }
}
