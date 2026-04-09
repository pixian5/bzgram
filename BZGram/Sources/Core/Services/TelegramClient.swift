import Foundation

public enum TelegramClientError: LocalizedError, Equatable {
    case invalidPhoneNumber
    case invalidCode
    case invalidPassword
    case unauthorized
    case chatNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please enter a valid phone number."
        case .invalidCode:
            return "The verification code is incorrect."
        case .invalidPassword:
            return "The two-step verification password is incorrect."
        case .unauthorized:
            return "Please sign in to continue."
        case .chatNotFound:
            return "The selected chat could not be found."
        }
    }
}

/// Abstraction over Telegram transport so the app can switch between mock and TDLib-backed implementations.
public protocol TelegramClient: Sendable {
    func authorizationState() async -> TelegramAuthorizationState
    func currentUser() async -> TelegramUser?
    func submitPhoneNumber(_ phoneNumber: String) async throws -> TelegramAuthorizationState
    func submitCode(_ code: String) async throws -> TelegramAuthorizationState
    func submitPassword(_ password: String) async throws -> TelegramAuthorizationState
    func logOut() async -> TelegramAuthorizationState
    func fetchChats() async throws -> [Chat]
    func fetchMessages(in chatID: Int64) async throws -> [Message]
    func sendMessage(_ text: String, to chatID: Int64) async throws -> Message
}
