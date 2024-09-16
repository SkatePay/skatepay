import Foundation
import MessageKit

struct MockUser: SenderType, Equatable {
  var senderId: String
  var displayName: String
}
