import Foundation

/// Temporary in-app Telegram backend used until TDLib is wired in.
/// The interface matches the real client layer so the UI and state flow can be built now.
public actor MockTelegramClient: TelegramClient {

    private var state: TelegramAuthorizationState = .waitingForPhoneNumber
    private var user: TelegramUser?
    private var chatsStorage: [Chat] = []
    private var messagesStorage: [Int64: [Message]] = [:]
    private var pendingPhoneNumber: String?

    public init() {}

    public func authorizationState() async -> TelegramAuthorizationState {
        state
    }

    public func currentUser() async -> TelegramUser? {
        user
    }

    public func submitPhoneNumber(_ phoneNumber: String) async throws -> TelegramAuthorizationState {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else {
            throw TelegramClientError.invalidPhoneNumber
        }
        pendingPhoneNumber = trimmed
        state = .waitingForCode(phoneNumber: trimmed)
        return state
    }

    public func submitCode(_ code: String) async throws -> TelegramAuthorizationState {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let phoneNumber = pendingPhoneNumber else {
            throw TelegramClientError.unauthorized
        }
        guard trimmed == "12345" else {
            throw TelegramClientError.invalidCode
        }

        user = TelegramUser(
            id: 1000001,
            displayName: "BZGram User",
            phoneNumber: phoneNumber
        )
        bootstrapDemoData(for: phoneNumber)
        state = .ready
        return state
    }

    public func submitPassword(_ password: String) async throws -> TelegramAuthorizationState {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "bzgram" else {
            throw TelegramClientError.invalidPassword
        }
        state = .ready
        return state
    }

    public func logOut() async -> TelegramAuthorizationState {
        state = .loggingOut
        user = nil
        chatsStorage = []
        messagesStorage = [:]
        pendingPhoneNumber = nil
        state = .waitingForPhoneNumber
        return state
    }

    public func fetchChats() async throws -> [Chat] {
        guard case .ready = state else {
            throw TelegramClientError.unauthorized
        }
        return chatsStorage
    }

    public func fetchMessages(in chatID: Int64) async throws -> [Message] {
        guard case .ready = state else {
            throw TelegramClientError.unauthorized
        }
        guard let messages = messagesStorage[chatID] else {
            throw TelegramClientError.chatNotFound
        }
        return messages.sorted { $0.date < $1.date }
    }

    public func sendMessage(_ text: String, to chatID: Int64) async throws -> Message {
        guard case .ready = state else {
            throw TelegramClientError.unauthorized
        }
        guard messagesStorage[chatID] != nil else {
            throw TelegramClientError.chatNotFound
        }

        let message = Message(
            id: Int64(Date().timeIntervalSince1970 * 1000),
            chatID: chatID,
            senderName: user?.displayName ?? "Me",
            originalText: text,
            date: Date(),
            isOutgoing: true
        )

        messagesStorage[chatID, default: []].append(message)
        if let index = chatsStorage.firstIndex(where: { $0.id == chatID }) {
            chatsStorage[index].lastMessageSnippet = text
            chatsStorage[index].lastMessageDate = message.date
        }
        return message
    }

    private func bootstrapDemoData(for phoneNumber: String) {
        let userName = "BZGram User"
        chatsStorage = [
            Chat(id: 1, title: "Telegram Service", type: .private, lastMessageSnippet: "Welcome to BZGram", lastMessageDate: Date().addingTimeInterval(-300), unreadCount: 0),
            Chat(id: 2, title: "Product Team", type: .group, lastMessageSnippet: "Roadmap sync at 4 PM", lastMessageDate: Date().addingTimeInterval(-1200), unreadCount: 3),
            Chat(id: 3, title: "Global News", type: .channel, lastMessageSnippet: "Daily briefing available", lastMessageDate: Date().addingTimeInterval(-7200), unreadCount: 8)
        ]

        messagesStorage = [
            1: [
                Message(id: 101, chatID: 1, senderName: "Telegram Service", originalText: "Welcome to BZGram.", date: Date().addingTimeInterval(-3600)),
                Message(id: 102, chatID: 1, senderName: userName, originalText: "Testing sign in from \(phoneNumber).", date: Date().addingTimeInterval(-3300), isOutgoing: true)
            ],
            2: [
                Message(id: 201, chatID: 2, senderName: "Alice", originalText: "Can we ship the login flow this week?", date: Date().addingTimeInterval(-2400)),
                Message(id: 202, chatID: 2, senderName: "Bob", originalText: "Yes, after the simulator build passes.", date: Date().addingTimeInterval(-2100)),
                Message(id: 203, chatID: 2, senderName: userName, originalText: "I am wiring the first TDLib-ready architecture now.", date: Date().addingTimeInterval(-1800), isOutgoing: true)
            ],
            3: [
                Message(id: 301, chatID: 3, senderName: "Global News", originalText: "Daily briefing available.", date: Date().addingTimeInterval(-7200)),
                Message(id: 302, chatID: 3, senderName: "Global News", originalText: "Markets opened mixed across Asia.", date: Date().addingTimeInterval(-5400))
            ]
        ]
    }
}
