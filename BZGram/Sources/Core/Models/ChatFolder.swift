import Foundation

/// Telegram 聊天文件夹（过滤器）
public struct ChatFolder: Identifiable, Equatable, Hashable {
    public let id: Int
    public let title: String
    
    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}
