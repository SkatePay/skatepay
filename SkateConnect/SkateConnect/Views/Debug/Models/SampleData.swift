
import AVFoundation
import CoreLocation
import MessageKit
import UIKit

final internal class SampleData {
    // MARK: Lifecycle
    
    private init() { }
    
    // MARK: Internal
    
    enum MessageTypes: String, CaseIterable {
        case Text
        case AttributedText
        case Photo
        case PhotoFromURL = "Photo from URL"
        case Video
        case Audio
        case Emoji
        case Location
        case Url
        case Phone
        case Custom
        case ShareContact
    }
    
    static let shared = SampleData()
    
    let system = MockUser(senderId: "000000", displayName: "System")
    let nathan = MockUser(senderId: "000001", displayName: "John")
    let steven = MockUser(senderId: "000002", displayName: "Paul")
    let wu = MockUser(senderId: "000003", displayName: "Luke")
    
    lazy var senders = [nathan, steven, wu]
    
    lazy var contactsToShare = [
        MockContactItem(name: "System", initials: "S"),
        MockContactItem(name: "John", initials: "NT", emails: ["test@test.com"]),
        MockContactItem(name: "Paul", initials: "SD", phoneNumbers: ["+1-202-555-0114", "+1-202-555-0145"]),
        MockContactItem(name: "Luke", initials: "WZ", phoneNumbers: ["202-555-0158"]),
        MockContactItem(name: "+40 123 123", initials: "#", phoneNumbers: ["+40 123 123"]),
        MockContactItem(name: "test@test.com", initials: "#", emails: ["test@test.com"]),
    ]
    
    var now = Date()
    
    let messageImages: [UIImage] = []
    let messageImageURLs: [URL] = [
        URL(string: "https://placekitten.com/g/200/300")!,
        URL(string: "https://placekitten.com/g/300/300")!,
        URL(string: "https://placekitten.com/g/300/400")!,
        URL(string: "https://placekitten.com/g/400/400")!,
    ]
    
    let emojis = [
        "👍",
        "😂😂😂",
        "👋👋👋",
        "😱😱😱",
        "😃😃😃",
        "❤️",
    ]
    
    let attributes = ["Font1", "Font2", "Font3", "Font4", "Color", "Combo"]
    
    let locations: [CLLocation] = [
        CLLocation(latitude: 37.3118, longitude: -122.0312),
        CLLocation(latitude: 33.6318, longitude: -100.0386),
        CLLocation(latitude: 29.3358, longitude: -108.8311),
        CLLocation(latitude: 39.3218, longitude: -127.4312),
        CLLocation(latitude: 35.3218, longitude: -127.4314),
        CLLocation(latitude: 39.3218, longitude: -113.3317),
    ]
    
    let sounds: [URL] = [
        //    Bundle.main.url(forResource: "sound1", withExtension: "m4a")!,
        //    Bundle.main.url(forResource: "sound2", withExtension: "m4a")!,
    ]
    
    let linkItem: (() -> MockLinkItem) = {
        MockLinkItem(
            text: "\(Lorem.sentence()) https://github.com/SkatePay",
            attributedText: nil,
            url: URL(string: "https://github.com/SkatePay")!,
            title: "SkatePay",
            teaser: "The App for Skater Friends!",
            thumbnailImage: UIImage(named: "user-skatepay")!)
    }
    
    var currentSender: MockUser {
        steven
    }
    
    func attributedString(with text: String) -> NSAttributedString {
        let nsString = NSString(string: text)
        var mutableAttributedString = NSMutableAttributedString(string: text)
        let randomAttribute = Int(arc4random_uniform(UInt32(attributes.count)))
        let range = NSRange(location: 0, length: nsString.length)
        
        switch attributes[randomAttribute] {
        case "Font1":
            mutableAttributedString.addAttribute(
                NSAttributedString.Key.font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: range)
        case "Font2":
            mutableAttributedString.addAttributes(
                [
                    NSAttributedString.Key.font: UIFont
                        .monospacedDigitSystemFont(ofSize: UIFont.systemFontSize, weight: UIFont.Weight.bold),
                ],
                range: range)
        case "Font3":
            mutableAttributedString.addAttributes(
                [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)],
                range: range)
        case "Font4":
            mutableAttributedString.addAttributes(
                [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: UIFont.systemFontSize)],
                range: range)
        case "Color":
            mutableAttributedString.addAttributes([NSAttributedString.Key.foregroundColor: UIColor.red], range: range)
        case "Combo":
            let msg9String = "Use .attributedText() to add bold, italic, colored text and more..."
            let msg9Text = NSString(string: msg9String)
            let msg9AttributedText = NSMutableAttributedString(string: String(msg9Text))
            
            msg9AttributedText.addAttribute(
                NSAttributedString.Key.font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: msg9Text.length))
            msg9AttributedText.addAttributes(
                [
                    NSAttributedString.Key.font: UIFont
                        .monospacedDigitSystemFont(ofSize: UIFont.systemFontSize, weight: UIFont.Weight.bold),
                ],
                range: msg9Text.range(of: ".attributedText()"))
            msg9AttributedText.addAttributes(
                [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)],
                range: msg9Text.range(of: "bold"))
            msg9AttributedText.addAttributes(
                [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: UIFont.systemFontSize)],
                range: msg9Text.range(of: "italic"))
            msg9AttributedText.addAttributes(
                [NSAttributedString.Key.foregroundColor: UIColor.red],
                range: msg9Text.range(of: "colored"))
            mutableAttributedString = msg9AttributedText
        default:
            fatalError("Unrecognized attribute for mock message")
        }
        
        return NSAttributedString(attributedString: mutableAttributedString)
    }
    
    func dateAddingRandomTime() -> Date {
        let randomNumber = Int(arc4random_uniform(UInt32(10)))
        if randomNumber % 2 == 0 {
            let date = Calendar.current.date(byAdding: .hour, value: randomNumber, to: now)!
            now = date
            return date
        } else {
            let randomMinute = Int(arc4random_uniform(UInt32(59)))
            let date = Calendar.current.date(byAdding: .minute, value: randomMinute, to: now)!
            now = date
            return date
        }
    }
    
    func randomMessageType() -> MessageTypes {
        MessageTypes.allCases.compactMap {
            guard UserDefaults.standard.bool(forKey: "\($0.rawValue)" + " Messages") else { return nil }
            return $0
        }.random()!
    }
    
    // swiftlint:disable cyclomatic_complexity
    func randomMessage(allowedSenders: [MockUser]) -> MockMessage {
        let uniqueID = UUID().uuidString
        let user = allowedSenders.random()!
        let date = dateAddingRandomTime()
        
        switch randomMessageType() {
        case .Text:
            let randomSentence = Lorem.sentence()
            return MockMessage(text: randomSentence, user: user, messageId: uniqueID, date: date)
        case .AttributedText:
            let randomSentence = Lorem.sentence()
            let attributedText = attributedString(with: randomSentence)
            return MockMessage(attributedText: attributedText, user: user, messageId: uniqueID, date: date)
        case .Photo:
            let image = messageImages.random()!
            return MockMessage(image: image, user: user, messageId: uniqueID, date: date)
        case .PhotoFromURL:
            let imageURL: URL = messageImageURLs.random()!
            return MockMessage(imageURL: imageURL, user: user, messageId: uniqueID, date: date)
        case .Video:
            let image = messageImages.random()!
            return MockMessage(thumbnail: image, user: user, messageId: uniqueID, date: date)
        case .Audio:
            let soundURL = sounds.random()!
            return MockMessage(audioURL: soundURL, user: user, messageId: uniqueID, date: date)
        case .Emoji:
            return MockMessage(emoji: emojis.random()!, user: user, messageId: uniqueID, date: date)
        case .Location:
            return MockMessage(location: locations.random()!, user: user, messageId: uniqueID, date: date)
        case .Url:
            return MockMessage(linkItem: linkItem(), user: user, messageId: uniqueID, date: date)
        case .Phone:
            return MockMessage(text: "123-456-7890", user: user, messageId: uniqueID, date: date)
        case .Custom:
            return MockMessage(custom: "Someone left the conversation", user: system, messageId: uniqueID, date: date)
        case .ShareContact:
            return MockMessage(contact: contactsToShare.random()!, user: user, messageId: uniqueID, date: date)
        }
    }
    
    // swiftlint:enable cyclomatic_complexity
    
    func getMessages(count: Int, completion: ([MockMessage]) -> Void) {
        var messages: [MockMessage] = []
        // Disable Custom Messages
        UserDefaults.standard.set(false, forKey: "Custom Messages")
        for _ in 0 ..< count {
            let uniqueID = UUID().uuidString
            let user = senders.random()!
            let date = dateAddingRandomTime()
            let randomSentence = Lorem.sentence()
            let message = MockMessage(text: randomSentence, user: user, messageId: uniqueID, date: date)
            messages.append(message)
        }
        completion(messages)
    }
    
    func getMessages(count: Int) -> [MockMessage] {
        var messages: [MockMessage] = []
        // Disable Custom Messages
        UserDefaults.standard.set(false, forKey: "Custom Messages")
        for _ in 0 ..< count {
            let uniqueID = UUID().uuidString
            let user = senders.random()!
            let date = dateAddingRandomTime()
            let randomSentence = Lorem.sentence()
            let message = MockMessage(text: randomSentence, user: user, messageId: uniqueID, date: date)
            messages.append(message)
        }
        return messages
    }
    
    func getAdvancedMessages(count: Int, completion: ([MockMessage]) -> Void) {
        var messages: [MockMessage] = []
        // Enable Custom Messages
        UserDefaults.standard.set(true, forKey: "Custom Messages")
        for _ in 0 ..< count {
            let message = randomMessage(allowedSenders: senders)
            messages.append(message)
        }
        completion(messages)
    }
    
    func getMessages(count: Int, allowedSenders _: [MockUser], completion: ([MockMessage]) -> Void) {
        var messages: [MockMessage] = []
        // Disable Custom Messages
        UserDefaults.standard.set(false, forKey: "Custom Messages")
        for _ in 0 ..< count {
            let uniqueID = UUID().uuidString
            let user = senders.random()!
            let date = dateAddingRandomTime()
            let randomSentence = Lorem.sentence()
            let message = MockMessage(text: randomSentence, user: user, messageId: uniqueID, date: date)
            messages.append(message)
        }
        completion(messages)
    }
    
    func getAvatarFor(sender: SenderType) -> Avatar {
        let firstName = sender.displayName.components(separatedBy: " ").first
        let lastName = sender.displayName.components(separatedBy: " ").first
        let initials = "\(firstName?.first ?? "A")\(lastName?.first ?? "A")"
        switch sender.senderId {
        case "000001":
            return Avatar(image: #imageLiteral(resourceName: "user-prorobot"), initials: initials)
        case "000002":
            return Avatar(image: #imageLiteral(resourceName: "user-skatepay"), initials: initials)
        case "000003":
            return Avatar(image: #imageLiteral(resourceName: "user-hub"), initials: initials)
        case "000000":
            return Avatar(image: nil, initials: "SS")
        default:
            return Avatar(image: nil, initials: isStringOneOfThree(sender.displayName))
        }
    }
}

func isStringSumOdd(_ input: String) -> Bool {
    let sum = input.unicodeScalars.map { Int($0.value) }.reduce(0, +)
    return sum % 2 != 0
}

func isStringOneOfThree(_ input: String) -> String {
    let sum = input.unicodeScalars.map { Int($0.value) }.reduce(0, +)
    
    // Use modulo 3 to cycle through the three emoji
    let remainder = sum % 3
    
    switch remainder {
    case 0:
        return "🙈"  // See no evil
    case 1:
        return "🙊"  // Speak no evil
    case 2:
        return "🙉"  // Hear no evil
    default:
        return "" // This will never be reached, but Swift requires a default case
    }
}
