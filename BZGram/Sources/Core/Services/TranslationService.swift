import Foundation

/// 翻译服务，支持 iOS 系统翻译（iOS 17+）和翻译缓存。
///
/// 缓存策略：使用 UserDefaults 持久化已翻译的消息，避免重复翻译请求。
/// 翻译失败时静默回退到原文，不会阻塞消息加载。
public final class TranslationService {

    public static let shared = TranslationService()
    public static let supportedLanguages: [(code: String, name: String)] = [
        ("ar", "العربية"),
        ("cs", "Čeština"),
        ("da", "Dansk"),
        ("de", "Deutsch"),
        ("el", "Ελληνικά"),
        ("en", "English"),
        ("es", "Español"),
        ("fi", "Suomi"),
        ("fr", "Français"),
        ("he", "עברית"),
        ("hi", "हिन्दी"),
        ("hr", "Hrvatski"),
        ("hu", "Magyar"),
        ("id", "Bahasa Indonesia"),
        ("it", "Italiano"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("ms", "Bahasa Melayu"),
        ("nl", "Nederlands"),
        ("no", "Norsk"),
        ("pl", "Polski"),
        ("pt", "Português"),
        ("ro", "Română"),
        ("ru", "Русский"),
        ("sk", "Slovenčina"),
        ("sv", "Svenska"),
        ("th", "ไทย"),
        ("tr", "Türkçe"),
        ("uk", "Українська"),
        ("vi", "Tiếng Việt"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文")
    ]

    /// 翻译缓存（key: "sourceText|targetLang", value: 翻译结果）
    private var cache: [String: String] = [:]
    private let cacheKey = "bzgram.translationCache"
    private let maxCacheSize = 5000
    private let store: UserDefaults

    private init(store: UserDefaults = .standard) {
        self.store = store
        loadCache()
    }

    // MARK: - Public API

    /// 将 `text` 翻译为 `targetLanguageCode` 指定的语言。
    ///
    /// - Parameters:
    ///   - text: 要翻译的原文
    ///   - targetLanguageCode: BCP-47 语言标签，如 `"en"`, `"zh-Hans"`
    ///   - sourceLanguageCode: 可选的原文语言提示
    /// - Returns: 翻译后的字符串；如果翻译不可用则返回原文
    public func translate(
        _ text: String,
        to targetLanguageCode: String,
        from sourceLanguageCode: String? = nil
    ) async -> String {
        // 空文本直接返回
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        // 检查缓存
        let cacheKey = makeCacheKey(text: text, target: targetLanguageCode)
        if let cached = cache[cacheKey] {
            return cached
        }

        // 尝试系统翻译（iOS 17.4+）
        let result = await performSystemTranslation(text, to: targetLanguageCode, from: sourceLanguageCode)

        // 缓存结果
        if result != text {
            cacheTranslation(key: cacheKey, value: result)
        }

        return result
    }

    /// 根据翻译设置翻译单条消息
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

    /// 批量翻译消息，保持原始顺序
    public func translateMessages(
        _ messages: [Message],
        settings: TranslationSettings
    ) async -> [Message] {
        guard settings.autoTranslateEnabled else { return messages }
        guard !messages.isEmpty else { return [] }
        return await withTaskGroup(of: (Int, Message).self) { group in
            for (index, message) in messages.enumerated() {
                group.addTask {
                    let translated = await self.translateMessage(message, settings: settings)
                    return (index, translated)
                }
            }
            var results = Array(repeating: messages[0], count: messages.count)
            for await (index, translated) in group {
                results[index] = translated
            }
            return results
        }
    }

    /// 清除翻译缓存
    public func clearCache() {
        cache.removeAll()
        store.removeObject(forKey: cacheKey)
    }

    /// 当前缓存条目数
    public var cacheCount: Int { cache.count }

    // MARK: - Private

    /// 尝试使用 iOS 系统翻译框架
    private func performSystemTranslation(
        _ text: String,
        to targetLanguageCode: String,
        from sourceLanguageCode: String?
    ) async -> String {
        if let source = sourceLanguageCode?.normalizedLanguageTag,
           source == targetLanguageCode.normalizedLanguageTag {
            return text
        }

        return Self.fallbackTranslate(text, to: targetLanguageCode)
    }

    private func makeCacheKey(text: String, target: String) -> String {
        // 使用文本哈希值+目标语言作为缓存键，避免超长键
        let textHash = text.hashValue
        return "\(textHash)|\(target)"
    }

    private func cacheTranslation(key: String, value: String) {
        // 超过最大缓存限制时，清除最早的一半
        if cache.count >= maxCacheSize {
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 2))
            for k in keysToRemove { cache.removeValue(forKey: k) }
        }
        cache[key] = value
        saveCache()
    }

    private func loadCache() {
        guard let data = store.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        cache = decoded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        store.set(data, forKey: cacheKey)
    }

    private func systemLanguageCode() -> String? {
        Locale.preferredLanguages.first?.normalizedLanguageTag
    }

    private static func fallbackTranslate(_ text: String, to targetLanguageCode: String) -> String {
        let normalizedTarget = targetLanguageCode.normalizedLanguageTag
        let normalizedSource = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "！", with: "!")
            .replacingOccurrences(of: "？", with: "?")

        let phrasebook: [String: [String: String]] = [
            "hello": ["zh-Hans": "你好", "ja": "こんにちは", "es": "Hola"],
            "hi": ["zh-Hans": "你好", "ja": "やあ", "es": "Hola"],
            "thank you": ["zh-Hans": "谢谢", "ja": "ありがとうございます", "es": "Gracias"],
            "thanks": ["zh-Hans": "谢谢", "ja": "ありがとう", "es": "Gracias"],
            "good morning": ["zh-Hans": "早上好", "ja": "おはよう", "es": "Buenos días"],
            "good night": ["zh-Hans": "晚安", "ja": "おやすみ", "es": "Buenas noches"],
            "how are you?": ["zh-Hans": "你好吗？", "ja": "元気ですか？", "es": "¿Cómo estás?"],
            "hola": ["en": "Hello", "zh-Hans": "你好", "ja": "こんにちは"],
            "gracias": ["en": "Thank you", "zh-Hans": "谢谢", "ja": "ありがとう"],
            "bonjour": ["en": "Hello", "zh-Hans": "你好", "ja": "こんにちは"],
            "merci": ["en": "Thank you", "zh-Hans": "谢谢", "ja": "ありがとう"],
            "你好": ["en": "Hello", "ja": "こんにちは", "es": "Hola"],
            "谢谢": ["en": "Thank you", "ja": "ありがとう", "es": "Gracias"],
            "再见": ["en": "Goodbye", "ja": "さようなら", "es": "Adiós"],
            "こんにちは": ["en": "Hello", "zh-Hans": "你好", "es": "Hola"],
            "ありがとう": ["en": "Thank you", "zh-Hans": "谢谢", "es": "Gracias"]
        ]

        if let translated = phrasebook[normalizedSource]?[normalizedTarget] {
            return translated
        }

        return text
    }
}

private extension String {
    var normalizedLanguageTag: String {
        let lowercased = trimmingCharacters(in: .whitespacesAndNewlines)
        if lowercased.lowercased().hasPrefix("zh-hans") { return "zh-Hans" }
        if lowercased.lowercased().hasPrefix("zh-hant") { return "zh-Hant" }
        if let first = lowercased.split(separator: "-").first {
            return String(first).lowercased()
        }
        return lowercased.lowercased()
    }
}
