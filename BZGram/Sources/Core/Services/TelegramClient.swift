import Foundation

public enum TelegramClientError: LocalizedError, Equatable {
    case invalidPhoneNumber
    case invalidCode
    case invalidPassword
    case unauthorized
    case chatNotFound
    case messageNotFound
    case networkError
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "请输入有效的手机号码。"
        case .invalidCode:
            return "验证码不正确。"
        case .invalidPassword:
            return "两步验证密码不正确。"
        case .unauthorized:
            return "请先登录再继续。"
        case .chatNotFound:
            return "找不到所选的对话。"
        case .messageNotFound:
            return "找不到指定的消息。"
        case .networkError:
            return "网络连接失败，请检查网络后重试。"
        case .unknown(let msg):
            return msg
        }
    }
}

/// TDLib 实时更新的回调接口
/// SessionStore 实现此协议以接收服务器推送的实时更新
public protocol TelegramUpdateDelegate: AnyObject, Sendable {
    /// 收到新消息
    @MainActor func didReceiveNewMessage(_ message: Message)
    /// 聊天列表发生变化（新聊天、最后消息更新等）
    @MainActor func didUpdateChat(_ chat: Chat)
    /// 聊天的未读计数发生变化
    @MainActor func didUpdateUnreadCount(chatID: Int64, unreadCount: Int)
    /// 消息内容被编辑
    @MainActor func didUpdateMessageContent(chatID: Int64, messageID: Int64, newText: String)
    /// 消息被删除
    @MainActor func didDeleteMessages(chatID: Int64, messageIDs: [Int64])
}

/// Telegram 传输层抽象，使 App 可以在 Mock 和 TDLib 实现之间切换。
public protocol TelegramClient: Sendable {
    // MARK: - 更新委托
    /// 设置实时更新委托（TDLib updateHandler 会回调此委托）
    func setUpdateDelegate(_ delegate: TelegramUpdateDelegate?) async

    // MARK: - 认证
    func authorizationState() async -> TelegramAuthorizationState
    func currentUser() async -> TelegramUser?
    func submitPhoneNumber(_ phoneNumber: String) async throws -> TelegramAuthorizationState
    func submitCode(_ code: String) async throws -> TelegramAuthorizationState
    func submitPassword(_ password: String) async throws -> TelegramAuthorizationState
    func logOut() async -> TelegramAuthorizationState

    // MARK: - 聊天
    func fetchChats() async throws -> [Chat]
    func fetchMessages(in chatID: Int64) async throws -> [Message]
    func sendMessage(_ text: String, to chatID: Int64) async throws -> Message
    func sendPhoto(filePath: String, caption: String, to chatID: Int64) async throws -> Message
    func sendVideo(filePath: String, caption: String, to chatID: Int64) async throws -> Message

    // MARK: - 增强操作
    func editMessage(messageID: Int64, in chatID: Int64, newText: String) async throws
    func deleteMessages(messageIDs: [Int64], in chatID: Int64) async throws
    func markChatAsRead(chatID: Int64) async throws
    func viewMessages(chatID: Int64, messageIDs: [Int64], forceRead: Bool) async throws
    func sendTypingAction(chatID: Int64, action: String) async throws
    func pinMessage(messageID: Int64, in chatID: Int64) async throws
    func unpinMessage(messageID: Int64, in chatID: Int64) async throws

    // MARK: - 搜索（委托给 TDLib 服务端分页过滤，避免内存中遍历全量消息）
    func searchMessages(query: String, in chatID: Int64, limit: Int) async throws -> [Message]

    // MARK: - 联系人
    func fetchContacts() async throws -> [Contact]

    // MARK: - 文件下载
    func downloadFile(remoteFileId: String) async throws -> String
}

/// 默认实现：保持向后兼容，使旧实现不需要立即改动所有方法
public extension TelegramClient {
    func setUpdateDelegate(_ delegate: TelegramUpdateDelegate?) async {}
    func editMessage(messageID: Int64, in chatID: Int64, newText: String) async throws {}
    func deleteMessages(messageIDs: [Int64], in chatID: Int64) async throws {}
    func markChatAsRead(chatID: Int64) async throws {}
    func viewMessages(chatID: Int64, messageIDs: [Int64], forceRead: Bool) async throws {}
    func sendTypingAction(chatID: Int64, action: String) async throws {}
    func pinMessage(messageID: Int64, in chatID: Int64) async throws {}
    func unpinMessage(messageID: Int64, in chatID: Int64) async throws {}
    func sendPhoto(filePath: String, caption: String, to chatID: Int64) async throws -> Message { throw TelegramClientError.unknown("Not implemented") }
    func sendVideo(filePath: String, caption: String, to chatID: Int64) async throws -> Message { throw TelegramClientError.unknown("Not implemented") }
    func searchMessages(query: String, in chatID: Int64, limit: Int) async throws -> [Message] { [] }
    func fetchContacts() async throws -> [Contact] { [] }
    func downloadFile(remoteFileId: String) async throws -> String { "" }
}
