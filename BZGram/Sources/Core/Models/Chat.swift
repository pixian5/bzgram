import Foundation

/// Telegram 聊天（私聊、群组、超级群组、频道）。
public struct Chat: Identifiable, Codable, Equatable {

    public let id: Int64
    public var title: String
    public var type: ChatType
    /// 该会话的翻译覆盖设置。为 `nil` 时使用全局 `AppSettings.globalTranslation`。
    public var translationOverride: TranslationSettings?
    /// 最后一条消息摘要（用于聊天列表展示）
    public var lastMessageSnippet: String?
    /// 最近消息的时间戳
    public var lastMessageDate: Date?
    /// 未读消息数
    public var unreadCount: Int
    /// 是否已置顶
    public var isPinned: Bool
    /// 是否已静音
    public var isMuted: Bool
    /// 是否已归档
    public var isArchived: Bool
    /// 最后一条消息的发送者名称
    public var lastMessageSenderName: String?
    /// 草稿消息
    public var draftMessage: String?

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
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isArchived: Bool = false,
        lastMessageSenderName: String? = nil,
        draftMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.translationOverride = translationOverride
        self.lastMessageSnippet = lastMessageSnippet
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isArchived = isArchived
        self.lastMessageSenderName = lastMessageSenderName
        self.draftMessage = draftMessage
    }

    /// 返回该聊天的有效翻译设置，回退到全局设置
    public func effectiveTranslation(globalSettings: TranslationSettings) -> TranslationSettings {
        translationOverride ?? globalSettings
    }

    /// 用于在列表中展示的描述性图标名称
    public var systemIconName: String {
        switch type {
        case .private:    return "person.fill"
        case .group:      return "person.3.fill"
        case .supergroup: return "person.3.fill"
        case .channel:    return "megaphone.fill"
        }
    }

    /// 聊天类型对应的强调色
    public var typeColor: String {
        switch type {
        case .private:    return "AccentColor"
        case .group:      return "green"
        case .supergroup: return "orange"
        case .channel:    return "red"
        }
    }
}
