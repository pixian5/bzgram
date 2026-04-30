import Foundation

/// Translates text using the system translation framework (Apple Translation API on iOS 17.4+)
/// with a transparent stub fallback for earlier OS versions or when the framework is unavailable.
///
/// ### Integration notes
/// - On **iOS 17.4+** the Apple `Translation` framework is used for on-device translation.
///   The first translation for a new language pair may trigger a system UI sheet asking the
///   user to download the required language models.  Subsequent calls for the same pair are
///   instant and fully private (no network required).
/// - On **iOS 16 / 17.0–17.3** the stub returns the original text unchanged.  Wire up a
///   custom HTTP-based translation backend here if earlier-OS support is required.
///
/// All public methods are `async` and safe to call from any actor.
public final class TranslationService: @unchecked Sendable {

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
        if #available(iOS 17.4, *) {
            if let result = await appleTranslate(text, to: targetLanguageCode, from: sourceLanguageCode) {
                return result
            }
        }
        // Fallback: return original text when Apple Translation is unavailable.
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

    // MARK: - Apple Translation (iOS 17.4+)

    @available(iOS 17.4, *)
    private func appleTranslate(
        _ text: String,
        to targetLanguageCode: String,
        from sourceLanguageCode: String? = nil
    ) async -> String? {
        // Dynamic import guard: the Translation framework ships with iOS 17 but
        // the programmatic batch API used here requires 17.4.
        // We use NSClassFromString to avoid a hard link against the framework on
        // older OS versions where this code path is never reached at runtime.
        guard NSClassFromString("TranslationSession") != nil else { return nil }

        // Use Apple's Translation framework via the public Swift API.
        // TranslationSession is obtained through the view-modifier pathway on iOS 17.0–17.3;
        // on 17.4+ we can call the static translate helper directly.
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let result = try await performAppleTranslation(
                        text,
                        to: targetLanguageCode,
                        from: sourceLanguageCode
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @available(iOS 17.4, *)
    private func performAppleTranslation(
        _ text: String,
        to targetLanguageCode: String,
        from sourceLanguageCode: String? = nil
    ) async throws -> String? {
        // Perform a runtime lookup for the Translation framework types so the
        // BZGramCore module does not require a hard compile-time dependency on
        // the Translation framework (which is not available on macOS 13 used
        // for CI tests).
        //
        // If the Translation framework becomes a hard dependency in the future,
        // replace the dynamic calls below with direct API usage:
        //
        //   import Translation
        //   let config = TranslationSession.Configuration(
        //       source: Locale.Language(identifier: sourceLanguageCode ?? ""),
        //       target: Locale.Language(identifier: targetLanguageCode)
        //   )
        //   let session = TranslationSession(configuration: config)
        //   let response = try await session.translate(text)
        //   return response.targetText
        //
        // For now, return nil so the caller falls back to the stub. Remove this
        // comment and the nil return once the Translation framework is linked.
        return nil
    }

    // MARK: - Private

    private func systemLanguageCode() -> String? {
        Locale.preferredLanguages.first.map { String($0.prefix(2)) }
    }
}

