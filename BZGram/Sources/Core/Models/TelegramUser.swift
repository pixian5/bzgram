import Foundation

/// Authenticated Telegram user profile.
public struct TelegramUser: Equatable, Sendable {
    public let id: Int64
    public var displayName: String
    public var phoneNumber: String

    public init(id: Int64, displayName: String, phoneNumber: String) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
    }
}
