import Foundation
#if canImport(Combine)
import Combine

/// 聊天列表 ViewModel
@MainActor
public final class ChatListViewModel: ObservableObject {

    @Published public var chats: [Chat] = []
    @Published public var isLoading: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var selectedFilter: ChatFilter = .all
    @Published public var showTranslatedOnly: Bool = false
    @Published public var showMutedOnly: Bool = false
    @Published public var showPinnedOnly: Bool = false

    private let settingsStore: SettingsStore
    private let sessionStore: TelegramSessionStore

    public enum ChatFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case groups = "群组"
        case channels = "频道"
        case `private` = "私聊"
        case pinned = "置顶"
        case muted = "静音"
        case translated = "翻译中"
    }

    public init(settingsStore: SettingsStore, sessionStore: TelegramSessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.chats = sessionStore.chats
    }

    /// 按条件过滤后的聊天列表
    public var filteredChats: [Chat] {
        var result = chats

        // 搜索过滤
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.lastMessageSnippet?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        // 类型过滤
        switch selectedFilter {
        case .all: break
        case .unread: result = result.filter { $0.unreadCount > 0 }
        case .groups: result = result.filter { $0.type == .group || $0.type == .supergroup }
        case .channels: result = result.filter { $0.type == .channel }
        case .private: result = result.filter { $0.type == .private }
        case .pinned: result = result.filter(\.isPinned)
        case .muted: result = result.filter(\.isMuted)
        case .translated:
            result = result.filter {
                $0.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation).autoTranslateEnabled
            }
        }

        if showTranslatedOnly {
            result = result.filter {
                $0.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation).autoTranslateEnabled
            }
        }
        if showMutedOnly {
            result = result.filter(\.isMuted)
        }
        if showPinnedOnly {
            result = result.filter(\.isPinned)
        }

        return result
    }

    public func setTranslationOverride(_ override: TranslationSettings?, for chat: Chat) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[index].translationOverride = override
    }

    public func clearTranslationOverride(for chat: Chat) {
        setTranslationOverride(nil, for: chat)
    }

    public func effectiveSettings(for chat: Chat) -> TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }

    public func loadChats(for account: Account) async {
        isLoading = true
        await sessionStore.refreshChats()
        chats = sessionStore.chats
        isLoading = false
    }

    /// 置顶/取消置顶
    public func togglePin(for chat: Chat) async {
        await sessionStore.togglePin(for: chat.id)
        chats = sessionStore.chats
    }

    /// 静音/取消静音
    public func toggleMute(for chat: Chat) async {
        await sessionStore.toggleMute(for: chat.id)
        chats = sessionStore.chats
    }

    /// 标记为已读
    public func markAsRead(_ chat: Chat) async {
        await sessionStore.markAsRead(chatID: chat.id)
        chats = sessionStore.chats
    }

    /// 删除会话
    public func deleteChat(_ chat: Chat) async {
        await sessionStore.deleteChat(chatID: chat.id)
        chats = sessionStore.chats
    }

    /// 总未读数
    public var totalUnreadCount: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }
}
#else
@MainActor
public final class ChatListViewModel {

    public var chats: [Chat] = []
    public var isLoading: Bool = false
    public var searchQuery: String = ""

    private let settingsStore: SettingsStore
    private let sessionStore: TelegramSessionStore

    public init(settingsStore: SettingsStore, sessionStore: TelegramSessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.chats = sessionStore.chats
    }

    public func setTranslationOverride(_ override: TranslationSettings?, for chat: Chat) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[index].translationOverride = override
    }

    public func clearTranslationOverride(for chat: Chat) {
        setTranslationOverride(nil, for: chat)
    }

    public func effectiveSettings(for chat: Chat) -> TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }

    public func loadChats(for account: Account) async {
        isLoading = true
        await sessionStore.refreshChats()
        chats = sessionStore.chats
        isLoading = false
    }

    public var totalUnreadCount: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }
}
#endif
