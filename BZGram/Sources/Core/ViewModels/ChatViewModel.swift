import Foundation
#if canImport(Combine)
import Combine

/// View-model for an open conversation.
public final class ChatViewModel: ObservableObject {

    @Published public var messages: [Message] = []
    @Published public var isLoading: Bool = false

    public let chat: Chat
    private let settingsStore: SettingsStore
    private let translationService: TranslationService

    public init(chat: Chat, settingsStore: SettingsStore, translationService: TranslationService = .shared) {
        self.chat = chat
        self.settingsStore = settingsStore
        self.translationService = translationService
    }

    public func loadMessages() async {
        await MainActor.run { isLoading = true }
        let raw: [Message] = [
            Message(id: 1, chatID: chat.id, senderName: chat.title, originalText: "Hola, ¿cómo estás?", date: Date().addingTimeInterval(-120)),
            Message(id: 2, chatID: chat.id, senderName: "Me", originalText: "Fine, thanks!", date: Date().addingTimeInterval(-60), isOutgoing: true),
            Message(id: 3, chatID: chat.id, senderName: chat.title, originalText: "Gut, auf Wiedersehen.", date: Date())
        ]
        let settings = effectiveSettings
        let translated = await translationService.translateMessages(raw, settings: settings)
        await MainActor.run {
            messages = translated
            isLoading = false
        }
    }

    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }
}
#else
/// View-model for an open conversation.
public final class ChatViewModel {

    public var messages: [Message] = []
    public var isLoading: Bool = false

    public let chat: Chat
    private let settingsStore: SettingsStore
    private let translationService: TranslationService

    public init(chat: Chat, settingsStore: SettingsStore, translationService: TranslationService = .shared) {
        self.chat = chat
        self.settingsStore = settingsStore
        self.translationService = translationService
    }

    /// Load and (if auto-translate is on) translate messages for this chat.
    public func loadMessages() async {
        isLoading = true
        let raw: [Message] = [
            Message(id: 1, chatID: chat.id, senderName: chat.title, originalText: "Hola, ¿cómo estás?", date: Date().addingTimeInterval(-120)),
            Message(id: 2, chatID: chat.id, senderName: "Me", originalText: "Fine, thanks!", date: Date().addingTimeInterval(-60), isOutgoing: true),
            Message(id: 3, chatID: chat.id, senderName: chat.title, originalText: "Gut, auf Wiedersehen.", date: Date())
        ]
        let settings = effectiveSettings
        let translated = await translationService.translateMessages(raw, settings: settings)
        messages = translated
        isLoading = false
    }

    /// The effective translation settings: per-chat override or global fallback.
    public var effectiveSettings: TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }
}
#endif
