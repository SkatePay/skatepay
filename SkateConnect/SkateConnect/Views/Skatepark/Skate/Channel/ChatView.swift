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

enum ContentType {
    case text(String)
    case video(URL)
    case photo(URL)
    case invite(String)
}

func processContent(content: String) -> ContentType {
    var text = content
    
    do {
        let decodedStructure = try JSONDecoder().decode(ContentStructure.self, from: content.data(using: .utf8)!)
        text = decodedStructure.content
        
        switch decodedStructure.kind {
        case .video:
            // Convert .mov to .jpg for the thumbnail
            let urlString = decodedStructure.content.replacingOccurrences(of: ".mov", with: ".jpg")
            if let url = URL(string: urlString) {
                return .video(url)
            } else {
                print("Invalid video thumbnail URL string: \(urlString)")
                return .text(decodedStructure.content) // Fallback to text
            }
        
        case .photo:
            // Handle photo content
            if let url = URL(string: decodedStructure.content) {
                return .photo(url)
            } else {
                print("Invalid photo URL string: \(decodedStructure.content)")
                return .text(decodedStructure.content) // Fallback to text
            }
        
        case .subscriber:
            // Format the subscriber text
            let formattedText = "🌴 \(friendlyKey(npub: text)) joined. 🛹"
            return .text(formattedText)
        
        default:
            // If no other kind is matched, fall through to check for channel_invite or return raw text
            break
        }
        
    } catch {
        print("Decoding error: \(error)")
    }
    
    // Handle channel_invite in the text as a fallback
    if let range = text.range(of: "channel_invite:") {
        let channelId = String(text[range.upperBound...])
        return .invite(channelId)
    }
    
    // Return the original text if no special cases are matched
    return .text(text)
}

struct ChatView: UIViewControllerRepresentable {
    let keychainForNostr = NostrKeychainStorage()

    func getCurrentUser() -> MockUser {
        guard let account = keychainForNostr.account else { return MockUser(senderId: "000002", displayName: "You") }
        return MockUser(senderId: account.publicKey.npub, displayName: "You")
    }
    
    final class Coordinator: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate {
        var parent: ChatView
        let onSend: (String) -> Void
        
        var supportUser: User?
        var currenUser: MockUser?
        
        init(_ parent: ChatView, onSend: @escaping (String) -> Void) {
            self.parent = parent
            self.onSend = onSend
            self.supportUser = AppData().getSupport()
            self.currenUser = parent.getCurrentUser()
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
        
        func messageTopLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
            var name = message.sender.displayName

            if (message.sender.senderId == self.supportUser?.npub) {
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
                return UIColor.systemPink
            }
            
            if (message.sender.senderId == self.supportUser?.npub) {
                return UIColor.systemOrange
            } else if (message.sender.senderId == currenUser?.senderId) {
                return UIColor.systemBlue
            } else {
                return UIColor.darkGray
            }
        }
        
        func messageTopLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
            16
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
    
    @State var initialized = false
    @Binding var messages: [MessageType]
    
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
        
        return messagesVC
    }
    
    func updateUIViewController(_ uiViewController: MessagesViewController, context _: Context) {
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
}
