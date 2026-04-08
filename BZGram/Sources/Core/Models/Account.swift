import Foundation

/// A Telegram account managed by BZGram.
/// BZGram imposes **no limit** on the number of accounts a user can add.
public struct Account: Identifiable, Codable, Equatable {
    /// Stable local identifier (not the Telegram user ID, which is only known after login).
    public let id: UUID
    /// Telegram numeric user identifier, available once authenticated.
    public var telegramUserID: Int64?
    /// Display name shown in the account switcher.
    public var displayName: String
    /// Phone number used to log in.
    public var phoneNumber: String
    /// Profile photo URL (remote or cached local path).
    public var avatarURL: URL?
    /// Whether this account is currently connected / authenticated.
    public var isAuthenticated: Bool
    /// Date the account was added to BZGram.
    public let addedAt: Date

    public init(
        id: UUID = UUID(),
        telegramUserID: Int64? = nil,
        displayName: String,
        phoneNumber: String,
        avatarURL: URL? = nil,
        isAuthenticated: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.telegramUserID = telegramUserID
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
        self.isAuthenticated = isAuthenticated
        self.addedAt = addedAt
    }
}
