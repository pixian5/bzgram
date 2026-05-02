import Foundation

/// 对话摘要结果。
public struct ChatSummary: Equatable, Sendable {
    public let headline: String
    public let bullets: [String]
    public let highlights: [String]

    public init(headline: String, bullets: [String], highlights: [String] = []) {
        self.headline = headline
        self.bullets = bullets
        self.highlights = highlights
    }

    public var formattedText: String {
        let bulletLines = bullets.map { "• \($0)" }
        let highlightLines = highlights.map { "重点：\($0)" }
        return ([headline] + bulletLines + highlightLines).joined(separator: "\n")
    }
}
