import Foundation

/// Translates text using the system translation framework (Apple Translation API on iOS 17+)
/// or a fallback HTTP-based translation API.
///
/// In this implementation a simple async stub is provided so that the architecture
/// and calling conventions are in place; a concrete backend can be wired in without
/// changing any call sites.
public final class TranslationService {

    public static let shared = TranslationService()

    private init() {}

    // MARK: - Public API

    /// Translate `text` into `targetLanguageCode`.
    ///
    /// - Parameters:
    ///   - text: The source text to translate.
    ///   - targetLanguageCode: BCP-47 language tag, e.g. `"en"`, `"zh-Hans"`.
    ///   - sourceLanguageCode: Optional hint for the source language.
    /// - Returns: The translated string, or the original `text` if translation is unavailable.
    public func translate(
        _ text: String,
        to targetLanguageCode: String,
        from sourceLanguageCode: String? = nil
    ) async -> String {
        // TODO: Wire up Apple Translation API (iOS 17+) or a custom HTTP backend.
        // For now the stub returns the original text so the rest of the app can be
        // developed and tested without a live translation endpoint.
        return text
    }

    /// Translate a `Message` according to the given `TranslationSettings`.
    ///
    /// The `translatedText` property of the returned message is populated when
    /// `settings.autoTranslateEnabled` is `true` and a `targetLanguageCode` is available.
    public func translateMessage(
        _ message: Message,
        settings: TranslationSettings
    ) async -> Message {
        guard settings.autoTranslateEnabled,
              let targetCode = settings.targetLanguageCode ?? systemLanguageCode()
        else {
            return message
        }
        var updated = message
        updated.translatedText = await translate(message.originalText, to: targetCode)
        return updated
    }

    /// Translate all messages in a batch according to `settings`.
    public func translateMessages(
        _ messages: [Message],
        settings: TranslationSettings
    ) async -> [Message] {
        guard settings.autoTranslateEnabled else { return messages }
        return await withTaskGroup(of: Message.self) { group in
            for message in messages {
                group.addTask { await self.translateMessage(message, settings: settings) }
            }
            var results: [Message] = []
            results.reserveCapacity(messages.count)
            for await translated in group {
                results.append(translated)
            }
            // Preserve original order.
            let idIndex = Dictionary(uniqueKeysWithValues: messages.enumerated().map { ($1.id, $0) })
            return results.sorted { (idIndex[$0.id] ?? 0) < (idIndex[$1.id] ?? 0) }
        }
    }

    // MARK: - Private

    private func systemLanguageCode() -> String? {
        Locale.preferredLanguages.first.map { String($0.prefix(2)) }
    }
}
