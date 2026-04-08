import Foundation

/// A Telegram chat (private, group, supergroup, channel).
public struct Chat: Identifiable, Codable, Equatable {
    public let id: Int64
    public var title: String
    public var type: ChatType
    /// Translation override for this specific conversation.
    /// When `nil` the global `AppSettings.globalTranslation` is used.
    public var translationOverride: TranslationSettings?
    /// Last message snippet shown in the chat list.
    public var lastMessageSnippet: String?
    /// Timestamp of the most recent message.
    public var lastMessageDate: Date?
    /// Number of unread messages.
    public var unreadCount: Int

    public enum ChatType: String, Codable {
        case `private`
        case group
        case supergroup
        case channel
    }

    public init(
        id: Int64,
        title: String,
        type: ChatType = .private,
        translationOverride: TranslationSettings? = nil,
        lastMessageSnippet: String? = nil,
        lastMessageDate: Date? = nil,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.translationOverride = translationOverride
        self.lastMessageSnippet = lastMessageSnippet
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
    }

    /// Returns the effective translation settings for this chat, falling back to the global setting.
    public func effectiveTranslation(globalSettings: TranslationSettings) -> TranslationSettings {
        translationOverride ?? globalSettings
    }
}
