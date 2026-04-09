import Foundation
#if canImport(Combine)
import Combine

/// View-model for an open conversation.
@MainActor
public final class ChatViewModel: ObservableObject {

    @Published public var messages: [Message] = []
    @Published public var isLoading: Bool = false
    @Published public var draftMessage: String = ""

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
        await MainActor.run { isLoading = true }
        await sessionStore.loadMessages(for: chat.id)
        let raw = sessionStore.messages(for: chat.id)
        let settings = effectiveSettings
        let translated = await translationService.translateMessages(raw, settings: settings)
        await MainActor.run {
            messages = translated
            isLoading = false
        }
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
#else
/// View-model for an open conversation.
@MainActor
public final class ChatViewModel {

    public var messages: [Message] = []
    public var isLoading: Bool = false
    public var draftMessage: String = ""

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

    /// Load and (if auto-translate is on) translate messages for this chat.
    public func loadMessages() async {
        isLoading = true
        await sessionStore.loadMessages(for: chat.id)
        let raw = sessionStore.messages(for: chat.id)
        let settings = effectiveSettings
        let translated = await translationService.translateMessages(raw, settings: settings)
        messages = translated
        isLoading = false
    }

    public func sendCurrentDraft() async {
        let outgoing = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }
        draftMessage = ""
        await sessionStore.sendMessage(outgoing, to: chat.id)
        await loadMessages()
    }

    /// The effective translation settings: per-chat override or global fallback.
    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }
}
#endif
