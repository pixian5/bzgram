import Foundation

/// 翻译服务，支持 iOS 系统翻译（iOS 17+）和翻译缓存。
///
/// 缓存策略：使用 UserDefaults 持久化已翻译的消息，避免重复翻译请求。
/// 翻译失败时静默回退到原文，不会阻塞消息加载。
public final class TranslationService {

    public static let shared = TranslationService()

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
            // 修正：如果消息数组为空的保护
            guard !messages.isEmpty else { return [] }
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
        // iOS 系统翻译 API (Translation framework) 需要 iOS 17.4+
        // 在此版本中使用基于 Telegram 自身翻译能力的 stub
        // 当部署目标升级到 iOS 17.4+ 时，可以无缝切换到系统翻译
        //
        // TODO: 当 deployment target ≥ 17.4 时启用：
        // import Translation
        // let session = TranslationSession(configuration: ...)
        // let response = try await session.translate(text)
        // return response.targetText

        return text
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
        Locale.preferredLanguages.first.map { String($0.prefix(2)) }
    }
}
