import Foundation

/// 基于最近消息的本地摘要服务。
public final class ChatSummaryService {

    public static let shared = ChatSummaryService()

    private init() {}

    public func summarize(
        messages: [Message],
        chatTitle: String,
        maxBullets: Int = 4
    ) -> ChatSummary {
        let meaningful = messages
            .map(\.originalText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !meaningful.isEmpty else {
            return ChatSummary(
                headline: "\(chatTitle) 暂无可摘要内容",
                bullets: ["最近没有可提炼的文本消息。"]
            )
        }

        let recent = Array(meaningful.suffix(20))
        let questionCount = recent.filter { $0.contains("?") || $0.contains("？") }.count
        let actionLike = recent.filter(Self.containsActionCue)
        let uniqueSpeakers = Set(messages.suffix(20).map(\.senderName)).count

        var bullets: [String] = []
        if let opening = recent.first {
            bullets.append("讨论从“\(Self.compact(opening, limit: 34))”展开。")
        }
        if let latest = recent.last, latest != recent.first {
            bullets.append("最新进展提到“\(Self.compact(latest, limit: 34))”。")
        }
        if questionCount > 0 {
            bullets.append("其中有 \(questionCount) 个待回应问题，建议优先处理未决事项。")
        }
        if !actionLike.isEmpty {
            bullets.append("出现了 \(min(actionLike.count, 3)) 条偏执行向的信息，像是在安排后续动作。")
        }
        if uniqueSpeakers > 1 {
            bullets.append("最近约有 \(uniqueSpeakers) 位参与者发言，讨论并非单向通知。")
        }

        var highlights = Self.topHighlights(in: recent)
        if highlights.isEmpty, let fallback = recent.last {
            highlights = [Self.compact(fallback, limit: 48)]
        }

        return ChatSummary(
            headline: "\(chatTitle) 最近在聊什么",
            bullets: Array(bullets.prefix(maxBullets)),
            highlights: Array(highlights.prefix(3))
        )
    }

    private static func containsActionCue(_ text: String) -> Bool {
        let keywords = ["需要", "安排", "上线", "修复", "跟进", "明天", "今天", "发布", "同步", "review", "todo", "ship", "fix", "follow up"]
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0.lowercased()) }
    }

    private static func topHighlights(in texts: [String]) -> [String] {
        let candidates = texts
            .filter { $0.count >= 8 }
            .sorted { score($0) > score($1) }
        var seen = Set<String>()
        var results: [String] = []
        for text in candidates {
            let compacted = compact(text, limit: 48)
            if seen.insert(compacted).inserted {
                results.append(compacted)
            }
            if results.count == 3 { break }
        }
        return results
    }

    private static func score(_ text: String) -> Int {
        var value = min(text.count, 60)
        if text.contains("?") || text.contains("？") { value += 10 }
        if containsActionCue(text) { value += 12 }
        if text.contains("!") || text.contains("！") { value += 3 }
        return value
    }

    private static func compact(_ text: String, limit: Int) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit - 1)) + "…"
    }
}
