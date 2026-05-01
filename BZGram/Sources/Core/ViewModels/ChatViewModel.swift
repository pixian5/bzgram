import Foundation
#if canImport(Combine)
import Combine

/// 单个对话的 ViewModel（消息收发 + 翻译 + 编辑/撤回）
/// 直接调用 TelegramSessionStore（已删除冗余 ChatService 中间层）
@MainActor
public final class ChatViewModel: ObservableObject {

    @Published public var messages: [Message] = []
    @Published public var isLoading: Bool = false
    @Published public var draftMessage: String = ""
    @Published public var editingMessage: Message?
    @Published public var replyToMessage: Message?
    @Published public var searchQuery: String = ""
    @Published public var isSearching: Bool = false
    @Published public var errorMessage: String?

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
        errorMessage = nil
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

    /// 发送当前草稿消息（带状态反馈）
    public func sendCurrentDraft() async {
        let outgoing = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }
        draftMessage = ""
        replyToMessage = nil
        errorMessage = nil
        // SessionStore.sendMessage 内部实现了 sending → sent/failed 状态机
        await sessionStore.sendMessage(outgoing, to: chat.id)
        // 同步 SessionStore 中的消息到本地（包含发送状态）
        messages = sessionStore.messages(for: chat.id)
        // 检查是否有发送失败的消息
        if let err = sessionStore.lastErrorMessage {
            errorMessage = err
        }
    }

    /// 重试发送失败的消息
    public func retryMessage(_ message: Message) async {
        errorMessage = nil
        await sessionStore.retryMessage(message)
        messages = sessionStore.messages(for: chat.id)
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

    /// 搜索消息（委托给 TDLib 服务端搜索）
    public func performSearch() async {
        guard !searchQuery.isEmpty else { return }
        let results = await sessionStore.searchMessages(query: searchQuery, in: chat.id)
        messages = results
    }

    /// 搜索过滤后的消息（本地快速过滤，用于 UI 即时响应）
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

    /// 是否有发送失败的消息
    public var hasFailedMessages: Bool {
        messages.contains { $0.sendStatus == .failed }
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
    public var errorMessage: String?

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
        messages = sessionStore.messages(for: chat.id)
    }

    public func retryMessage(_ message: Message) async {
        await sessionStore.retryMessage(message)
        messages = sessionStore.messages(for: chat.id)
    }

    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }

    public var hasFailedMessages: Bool {
        messages.contains { $0.sendStatus == .failed }
    }
}
#endif
