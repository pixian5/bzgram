import Foundation

/// Authorization phases exposed by the Telegram client layer.
public enum TelegramAuthorizationState: Equatable {
    case waitingForPhoneNumber
    case waitingForCode(phoneNumber: String)
    case waitingForPassword(phoneNumber: String, hint: String?)
    case ready
    case loggingOut
}
