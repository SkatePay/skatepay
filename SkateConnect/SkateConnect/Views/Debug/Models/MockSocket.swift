import MessageKit
import UIKit

final class MockSocket {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static var shared = MockSocket()

  @discardableResult
  func connect(with senders: [MockUser]) -> Self {
    disconnect()
    connectedUsers = senders
    timer = Timer.scheduledTimer(
      timeInterval: 2.5,
      target: self,
      selector: #selector(handleTimer),
      userInfo: nil,
      repeats: true)
    return self
  }

  @discardableResult
  func disconnect() -> Self {
    timer?.invalidate()
    timer = nil
    onTypingStatusCode = nil
    onNewMessageCode = nil
    return self
  }

  @discardableResult
  func onNewMessage(code: @escaping (MockMessage) -> Void) -> Self {
    onNewMessageCode = code
    return self
  }

  @discardableResult
  func onTypingStatus(code: @escaping () -> Void) -> Self {
    onTypingStatusCode = code
    return self
  }

  // MARK: Private

  private var timer: Timer?

  private var queuedMessage: MockMessage?

  private var onNewMessageCode: ((MockMessage) -> Void)?

  private var onTypingStatusCode: (() -> Void)?

  private var connectedUsers: [MockUser] = []

  @objc
  private func handleTimer() {
    if let message = queuedMessage {
      onNewMessageCode?(message)
      queuedMessage = nil
    } else {
      let sender = connectedUsers.random()!
      let message = SampleData.shared.randomMessage(allowedSenders: [sender])
      queuedMessage = message
      onTypingStatusCode?()
    }
  }
}
