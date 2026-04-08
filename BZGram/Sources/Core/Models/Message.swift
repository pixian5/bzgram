import Foundation

/// A single message in a conversation.
public struct Message: Identifiable, Codable, Equatable {
    public let id: Int64
    public let chatID: Int64
    public let senderName: String
    public let originalText: String
    /// Translated text, populated by `TranslationService` when auto-translate is active.
    public var translatedText: String?
    public let date: Date
    public let isOutgoing: Bool

    public init(
        id: Int64,
        chatID: Int64,
        senderName: String,
        originalText: String,
        translatedText: String? = nil,
        date: Date = Date(),
        isOutgoing: Bool = false
    ) {
        self.id = id
        self.chatID = chatID
        self.senderName = senderName
        self.originalText = originalText
        self.translatedText = translatedText
        self.date = date
        self.isOutgoing = isOutgoing
    }

    /// The text to display according to `settings`.
    ///
    /// - If auto-translate is on and a translation is available, returns the translated text.
    /// - Otherwise returns the original text.
    public func displayText(settings: TranslationSettings) -> String {
        guard settings.autoTranslateEnabled, let translated = translatedText else {
            return originalText
        }
        return translated
    }
}
