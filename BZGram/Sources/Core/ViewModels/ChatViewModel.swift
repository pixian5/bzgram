import Foundation
#if canImport(Combine)
import Combine

/// 单个对话的 ViewModel（消息收发 + 翻译 + 编辑/撤回）
@MainActor
public final class ChatViewModel: ObservableObject {

    @Published public var messages: [Message] = []
    @Published public var isLoading: Bool = false
    @Published public var draftMessage: String = ""
    @Published public var editingMessage: Message?
    @Published public var replyToMessage: Message?
    @Published public var searchQuery: String = ""
    @Published public var isSearching: Bool = false

    public let chat: Chat
    private let settingsStore: SettingsStore
    private let translationService: TranslationService
    private let sessionStore: TelegramSessionStore

    public init(
        chat: Chat,
        settingsStore: SettingsStore,
        sessionStore: TelegramSessionStore,
        translationService: TranslationService = .shared
    ) {
        self.chat = chat
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.translationService = translationService
    }

    /// 加载消息并翻译
    public func loadMessages() async {
        isLoading = true
        await sessionStore.loadMessages(for: chat.id)
        let raw = sessionStore.messages(for: chat.id)
        let settings = effectiveSettings
        if settings.autoTranslateEnabled {
            messages = await translationService.translateMessages(raw, settings: settings)
        } else {
            messages = raw
        }
        isLoading = false
    }

    /// 发送当前草稿消息
    public func sendCurrentDraft() async {
        let outgoing = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }
        draftMessage = ""
        replyToMessage = nil
        await sessionStore.sendMessage(outgoing, to: chat.id)
        await loadMessages()
    }

    /// 编辑消息
    public func startEditing(_ message: Message) {
        editingMessage = message
        draftMessage = message.originalText
    }

    /// 提交编辑
    public func submitEdit() async {
        guard let editing = editingMessage else { return }
        let newText = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else { return }
        draftMessage = ""
        editingMessage = nil
        await sessionStore.editMessage(messageID: editing.id, in: chat.id, newText: newText)
        await loadMessages()
    }

    /// 取消编辑
    public func cancelEditing() {
        editingMessage = nil
        draftMessage = ""
    }

    /// 撤回/删除消息
    public func deleteMessage(_ message: Message) async {
        await sessionStore.deleteMessage(messageID: message.id, in: chat.id)
        messages.removeAll { $0.id == message.id }
    }

    /// 设置回复消息
    public func setReply(to message: Message) {
        replyToMessage = message
    }

    /// 取消回复
    public func cancelReply() {
        replyToMessage = nil
    }

    /// 搜索消息
    public var filteredMessages: [Message] {
        guard !searchQuery.isEmpty else { return messages }
        return messages.filter {
            $0.originalText.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.translatedText?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    /// 有效的翻译设置
    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }

    /// 是否处于编辑模式
    public var isEditing: Bool {
        editingMessage != nil
    }
}
#else
@MainActor
public final class ChatViewModel {

    public var messages: [Message] = []
    public var isLoading: Bool = false
    public var draftMessage: String = ""
    public var editingMessage: Message?
    public var replyToMessage: Message?

    public let chat: Chat
    private let settingsStore: SettingsStore
    private let translationService: TranslationService
    private let sessionStore: TelegramSessionStore

    public init(
        chat: Chat,
        settingsStore: SettingsStore,
        sessionStore: TelegramSessionStore,
        translationService: TranslationService = .shared
    ) {
        self.chat = chat
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.translationService = translationService
    }

    public func loadMessages() async {
        isLoading = true
        await sessionStore.loadMessages(for: chat.id)
        let raw = sessionStore.messages(for: chat.id)
        let settings = effectiveSettings
        if settings.autoTranslateEnabled {
            messages = await translationService.translateMessages(raw, settings: settings)
        } else {
            messages = raw
        }
        isLoading = false
    }

    public func sendCurrentDraft() async {
        let outgoing = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }
        draftMessage = ""
        await sessionStore.sendMessage(outgoing, to: chat.id)
        await loadMessages()
    }

    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }
}
#endif
