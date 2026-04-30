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

/// Telegram 传输层抽象，使 App 可以在 Mock 和 TDLib 实现之间切换。
public protocol TelegramClient: Sendable {
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

    // MARK: - 增强操作
    func editMessage(messageID: Int64, in chatID: Int64, newText: String) async throws
    func deleteMessages(messageIDs: [Int64], in chatID: Int64) async throws
    func markChatAsRead(chatID: Int64) async throws
}

/// 为协议提供默认实现（向后兼容，使旧实现不需要立即改动）
public extension TelegramClient {
    func editMessage(messageID: Int64, in chatID: Int64, newText: String) async throws {
        // 默认无操作
    }
    func deleteMessages(messageIDs: [Int64], in chatID: Int64) async throws {
        // 默认无操作
    }
    func markChatAsRead(chatID: Int64) async throws {
        // 默认无操作
    }
}
