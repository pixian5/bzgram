import Foundation

/// Translation settings that can be applied globally **or** overridden per conversation.
public struct TranslationSettings: Codable, Equatable {

    // MARK: - Target language

    /// BCP-47 language tag for the language messages should be translated into.
    /// e.g. `"en"`, `"zh-Hans"`, `"es"`, `"fr"`.
    /// When `nil` the system/device preferred language is used.
    public var targetLanguageCode: String?

    // MARK: - Behaviour toggles

    /// When `true`, incoming messages are automatically translated without user interaction.
    public var autoTranslateEnabled: Bool

    /// When `true`, the original message text is shown beneath the translation.
    public var showOriginalText: Bool

    // MARK: - Initialiser

    /// Create translation settings.
    /// - Parameters:
    ///   - targetLanguageCode: BCP-47 language tag, or `nil` to follow system language.
    ///   - autoTranslateEnabled: Whether auto-translation is active.
    ///   - showOriginalText: Whether to display the original alongside the translation.
    public init(
        targetLanguageCode: String? = nil,
        autoTranslateEnabled: Bool = false,
        showOriginalText: Bool = true
    ) {
        self.targetLanguageCode = targetLanguageCode
        self.autoTranslateEnabled = autoTranslateEnabled
        self.showOriginalText = showOriginalText
    }

    /// Convenience preset: auto-translate to the given language, showing original text.
    public static func autoTranslate(to languageCode: String, showOriginal: Bool = true) -> TranslationSettings {
        TranslationSettings(
            targetLanguageCode: languageCode,
            autoTranslateEnabled: true,
            showOriginalText: showOriginal
        )
    }

    /// Convenience preset: translation disabled.
    public static var disabled: TranslationSettings {
        TranslationSettings(autoTranslateEnabled: false)
    }
}
