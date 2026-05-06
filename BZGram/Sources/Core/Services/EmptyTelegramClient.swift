import Foundation

/// 一个安全的、不执行任何操作的 TelegramClient 实现。
/// 用于在 App 尚未登录任何账号或处于初始化状态时，防止程序因访问活跃客户端而崩溃。
public final class EmptyTelegramClient: TelegramClient {
    public init() {}
    
    public func setUpdateDelegate(_ delegate: TelegramUpdateDelegate?) async {}
    
    public func authorizationState() async -> TelegramAuthorizationState {
        return .waitingForPhoneNumber
    }
    
    public func currentUser() async -> TelegramUser? {
        return nil
    }
    
    public func submitPhoneNumber(_ phoneNumber: String) async throws -> TelegramAuthorizationState {
        throw TelegramClientError.unauthorized
    }
    
    public func resendAuthenticationCode() async throws -> TelegramAuthorizationState {
        throw TelegramClientError.unauthorized
    }
    
    public func submitCode(_ code: String) async throws -> TelegramAuthorizationState {
        throw TelegramClientError.unauthorized
    }
    
    public func submitPassword(_ password: String) async throws -> TelegramAuthorizationState {
        throw TelegramClientError.unauthorized
    }
    
    public func logOut() async -> TelegramAuthorizationState {
        return .waitingForPhoneNumber
    }
    
    public func fetchChats() async throws -> [Chat] {
        return []
    }
    
    public func fetchMessages(in chatID: Int64) async throws -> [Message] {
        return []
    }
    
    public func sendMessage(_ text: String, to chatID: Int64) async throws -> Message {
        throw TelegramClientError.unauthorized
    }
}
