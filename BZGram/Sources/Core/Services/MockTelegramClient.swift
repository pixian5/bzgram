import Foundation

/// 临时的应用内 Telegram 后端，用于 UI 开发和测试。
/// 接口与真实客户端层一致，便于无缝切换。
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
            isOutgoing: true,
            canBeEdited: true
        )

        messagesStorage[chatID, default: []].append(message)
        if let index = chatsStorage.firstIndex(where: { $0.id == chatID }) {
            chatsStorage[index].lastMessageSnippet = text
            chatsStorage[index].lastMessageDate = message.date
            chatsStorage[index].lastMessageSenderName = user?.displayName
        }
        return message
    }

    public func editMessage(messageID: Int64, in chatID: Int64, newText: String) async throws {
        guard var messages = messagesStorage[chatID] else {
            throw TelegramClientError.chatNotFound
        }
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw TelegramClientError.messageNotFound
        }
        // 由于 Message 是 struct，需要创建新的实例
        let old = messages[index]
        let updated = Message(
            id: old.id,
            chatID: old.chatID,
            senderName: old.senderName,
            senderUserID: old.senderUserID,
            originalText: newText,
            translatedText: nil,
            date: old.date,
            isOutgoing: old.isOutgoing,
            contentType: old.contentType,
            attachment: old.attachment,
            isEdited: true,
            replyToMessageId: old.replyToMessageId,
            canBeDeleted: old.canBeDeleted,
            canBeEdited: old.canBeEdited
        )
        messages[index] = updated
        messagesStorage[chatID] = messages
    }

    public func deleteMessages(messageIDs: [Int64], in chatID: Int64) async throws {
        guard messagesStorage[chatID] != nil else {
            throw TelegramClientError.chatNotFound
        }
        messagesStorage[chatID]?.removeAll { messageIDs.contains($0.id) }
    }

    public func markChatAsRead(chatID: Int64) async throws {
        guard let index = chatsStorage.firstIndex(where: { $0.id == chatID }) else {
            throw TelegramClientError.chatNotFound
        }
        chatsStorage[index].unreadCount = 0
    }

    // MARK: - 演示数据

    private func bootstrapDemoData(for phoneNumber: String) {
        let userName = "BZGram User"
        chatsStorage = [
            Chat(id: 1, title: "Telegram 服务通知", type: .private,
                 lastMessageSnippet: "欢迎使用 BZGram",
                 lastMessageDate: Date().addingTimeInterval(-300),
                 unreadCount: 0,
                 lastMessageSenderName: "Telegram"),
            Chat(id: 2, title: "产品团队", type: .group,
                 lastMessageSnippet: "下午 4 点同步进度",
                 lastMessageDate: Date().addingTimeInterval(-1200),
                 unreadCount: 3,
                 lastMessageSenderName: "Alice"),
            Chat(id: 3, title: "全球新闻", type: .channel,
                 lastMessageSnippet: "每日简报已发布",
                 lastMessageDate: Date().addingTimeInterval(-7200),
                 unreadCount: 8),
            Chat(id: 4, title: "开发频道", type: .supergroup,
                 lastMessageSnippet: "新版本发布 🎉",
                 lastMessageDate: Date().addingTimeInterval(-3600),
                 unreadCount: 2,
                 isPinned: true,
                 lastMessageSenderName: "Bot")
        ]

        messagesStorage = [
            1: [
                Message(id: 101, chatID: 1, senderName: "Telegram", originalText: "欢迎使用 BZGram。",
                        date: Date().addingTimeInterval(-3600)),
                Message(id: 102, chatID: 1, senderName: userName,
                        originalText: "从 \(phoneNumber) 测试登录。",
                        date: Date().addingTimeInterval(-3300), isOutgoing: true, canBeEdited: true)
            ],
            2: [
                Message(id: 201, chatID: 2, senderName: "Alice",
                        originalText: "这周能上线登录流程吗？",
                        date: Date().addingTimeInterval(-2400)),
                Message(id: 202, chatID: 2, senderName: "Bob",
                        originalText: "可以，模拟器构建通过后就上线。",
                        date: Date().addingTimeInterval(-2100)),
                Message(id: 203, chatID: 2, senderName: userName,
                        originalText: "我正在搭建第一版 TDLib 架构。",
                        date: Date().addingTimeInterval(-1800), isOutgoing: true, canBeEdited: true)
            ],
            3: [
                Message(id: 301, chatID: 3, senderName: "全球新闻",
                        originalText: "每日简报已发布。",
                        date: Date().addingTimeInterval(-7200)),
                Message(id: 302, chatID: 3, senderName: "全球新闻",
                        originalText: "亚洲市场开盘涨跌不一。",
                        date: Date().addingTimeInterval(-5400))
            ],
            4: [
                Message(id: 401, chatID: 4, senderName: "Bot",
                        originalText: "BZGram v1.0.0 已发布！🎉",
                        date: Date().addingTimeInterval(-3600)),
                Message(id: 402, chatID: 4, senderName: "Dev",
                        originalText: "多账号和翻译功能已就绪。",
                        date: Date().addingTimeInterval(-3000))
            ]
        ]
    }
}
