import Foundation

/// TDLib 聊天操作封装服务。
/// 提供消息发送/接收/撤回/编辑、会话管理等能力。
@MainActor
public final class ChatService {

    private let sessionStore: TelegramSessionStore

    public init(sessionStore: TelegramSessionStore) {
        self.sessionStore = sessionStore
    }

    // MARK: - 会话管理

    /// 刷新聊天列表
    public func refreshChats() async {
        await sessionStore.refreshChats()
    }

    /// 置顶/取消置顶会话（本地标记）
    public func togglePin(for chatID: Int64) async {
        await sessionStore.togglePin(for: chatID)
    }

    /// 标记会话为已读
    public func markAsRead(chatID: Int64) async {
        await sessionStore.markAsRead(chatID: chatID)
    }

    /// 删除会话
    public func deleteChat(chatID: Int64) async {
        await sessionStore.deleteChat(chatID: chatID)
    }

    /// 静音/取消静音会话（本地标记）
    public func toggleMute(for chatID: Int64) async {
        await sessionStore.toggleMute(for: chatID)
    }

    // MARK: - 消息操作

    /// 加载某个聊天的消息历史
    public func loadMessages(for chatID: Int64) async -> [Message] {
        await sessionStore.loadMessages(for: chatID)
        return sessionStore.messages(for: chatID)
    }

    /// 发送文本消息
    public func sendMessage(_ text: String, to chatID: Int64) async {
        await sessionStore.sendMessage(text, to: chatID)
    }

    /// 编辑已发送的消息
    public func editMessage(messageID: Int64, in chatID: Int64, newText: String) async {
        await sessionStore.editMessage(messageID: messageID, in: chatID, newText: newText)
    }

    /// 撤回消息
    public func deleteMessage(messageID: Int64, in chatID: Int64) async {
        await sessionStore.deleteMessage(messageID: messageID, in: chatID)
    }

    /// 搜索消息
    public func searchMessages(query: String, in chatID: Int64? = nil) async -> [Message] {
        // 如果指定了 chatID，在该聊天内搜索；否则全局搜索
        let messages: [Message]
        if let chatID = chatID {
            messages = sessionStore.messages(for: chatID)
        } else {
            messages = sessionStore.messagesByChatID.values.flatMap { $0 }
        }

        guard !query.isEmpty else { return messages }
        return messages.filter {
            $0.originalText.localizedCaseInsensitiveContains(query)
        }
    }
}
