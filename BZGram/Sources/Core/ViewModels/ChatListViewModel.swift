import Foundation
#if canImport(Combine)
import Combine

/// View-model for the chat list of the active account.
@MainActor
public final class ChatListViewModel: ObservableObject {

    @Published public var chats: [Chat] = []
    @Published public var isLoading: Bool = false

    private let settingsStore: SettingsStore
    public let sessionStore: TelegramSessionStore

    private var cancellables: Set<AnyCancellable> = []

    public init(settingsStore: SettingsStore, sessionStore: TelegramSessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.chats = sessionStore.chats

        // Automatically reflect chat list changes published by the session store.
        sessionStore.$chats
            .receive(on: RunLoop.main)
            .assign(to: &$chats)
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
        await MainActor.run { isLoading = true }
        await sessionStore.refreshChats()
        await MainActor.run {
            chats = sessionStore.chats
            isLoading = false
        }
    }
}
#else
/// View-model for the chat list of the active account.
@MainActor
public final class ChatListViewModel {

    public var chats: [Chat] = []
    public var isLoading: Bool = false

    private let settingsStore: SettingsStore
    public let sessionStore: TelegramSessionStore

    public init(settingsStore: SettingsStore, sessionStore: TelegramSessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.chats = sessionStore.chats
    }

    /// Update the per-conversation translation override.
    public func setTranslationOverride(_ override: TranslationSettings?, for chat: Chat) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[index].translationOverride = override
    }

    /// Clear the per-conversation override so the chat falls back to the global setting.
    public func clearTranslationOverride(for chat: Chat) {
        setTranslationOverride(nil, for: chat)
    }

    /// Returns the effective `TranslationSettings` for `chat`.
    public func effectiveSettings(for chat: Chat) -> TranslationSettings {
        chat.effectiveTranslation(globalSettings: settingsStore.settings.globalTranslation)
    }

    /// Load chats for the given account (stub implementation).
    public func loadChats(for account: Account) async {
        isLoading = true
        await sessionStore.refreshChats()
        chats = sessionStore.chats
        isLoading = false
    }
}
#endif
