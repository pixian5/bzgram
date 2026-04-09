import Foundation
@preconcurrency import TDLibKit

public actor TDLibTelegramClient: TelegramClient {

    private static let manager = TDLibClientManager()

    private let configuration: TelegramAPIConfiguration
    private var client: TDLibClient
    private var state: TelegramAuthorizationState = .waitingForPhoneNumber
    private var currentTDLibState: AuthorizationState = .authorizationStateWaitTdlibParameters
    private var currentTelegramUser: TelegramUser?
    private var cachedUsers: [Int64: User] = [:]
    private var cachedChats: [Int64: TDLibKit.Chat] = [:]

    public init(configuration: TelegramAPIConfiguration) {
        self.configuration = configuration
        self.client = Self.manager.createClient(updateHandler: { _, _ in })
    }

    public func authorizationState() async -> TelegramAuthorizationState {
        do {
            try await refreshAuthorizationState()
        } catch {
            state = .waitingForPhoneNumber
        }
        return state
    }

    public func currentUser() async -> TelegramUser? {
        if case .ready = state, currentTelegramUser == nil {
            currentTelegramUser = try? await fetchCurrentUser()
        }
        return currentTelegramUser
    }

    public func submitPhoneNumber(_ phoneNumber: String) async throws -> TelegramAuthorizationState {
        let normalizedPhoneNumber = Self.normalizePhoneNumber(phoneNumber)
        guard normalizedPhoneNumber.count >= 7 else {
            throw TelegramClientError.invalidPhoneNumber
        }

        try await ensureInitialized()
        try await client.setAuthenticationPhoneNumber(
            phoneNumber: normalizedPhoneNumber,
            settings: PhoneNumberAuthenticationSettings(
                allowFlashCall: false,
                allowMissedCall: false,
                allowSmsRetrieverApi: false,
                authenticationTokens: [],
                firebaseAuthenticationSettings: nil,
                hasUnknownPhoneNumber: false,
                isCurrentPhoneNumber: false
            )
        )
        try await refreshAuthorizationState()
        return state
    }

    public func submitCode(_ code: String) async throws -> TelegramAuthorizationState {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TelegramClientError.invalidCode
        }

        try await ensureInitialized()
        do {
            try await client.checkAuthenticationCode(code: trimmed)
        } catch {
            throw map(error: error)
        }

        try await refreshAuthorizationState()
        if case .ready = state {
            currentTelegramUser = try? await fetchCurrentUser()
        }
        return state
    }

    public func submitPassword(_ password: String) async throws -> TelegramAuthorizationState {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TelegramClientError.invalidPassword
        }

        try await ensureInitialized()
        do {
            try await client.checkAuthenticationPassword(password: trimmed)
        } catch {
            throw map(error: error)
        }

        try await refreshAuthorizationState()
        if case .ready = state {
            currentTelegramUser = try? await fetchCurrentUser()
        }
        return state
    }

    public func logOut() async -> TelegramAuthorizationState {
        do {
            try await ensureInitialized()
            try await client.logOut()
        } catch {
            _ = try? await client.close()
        }

        currentTelegramUser = nil
        cachedUsers = [:]
        cachedChats = [:]
        rebuildClient()
        state = .waitingForPhoneNumber
        currentTDLibState = .authorizationStateWaitTdlibParameters
        return state
    }

    public func fetchChats() async throws -> [Chat] {
        try await ensureAuthorized()

        let ids = try await client.getChats(chatList: .chatListMain, limit: 100).chatIds
        var chats: [Chat] = []
        chats.reserveCapacity(ids.count)

        for chatID in ids {
            let tdChat = try await client.getChat(chatId: chatID)
            cachedChats[chatID] = tdChat
            chats.append(map(chat: tdChat))
        }

        return chats.sorted { lhs, rhs in
            (lhs.lastMessageDate ?? .distantPast) > (rhs.lastMessageDate ?? .distantPast)
        }
    }

    public func fetchMessages(in chatID: Int64) async throws -> [Message] {
        try await ensureAuthorized()

        let history = try await client.getChatHistory(
            chatId: chatID,
            fromMessageId: 0,
            limit: 100,
            offset: 0,
            onlyLocal: false
        )

        let tdMessages = history.messages ?? []
        var mapped: [Message] = []
        mapped.reserveCapacity(tdMessages.count)
        for tdMessage in tdMessages {
            if let message = try await map(message: tdMessage) {
                mapped.append(message)
            }
        }

        return mapped.sorted { $0.date < $1.date }
    }

    public func sendMessage(_ text: String, to chatID: Int64) async throws -> Message {
        try await ensureAuthorized()

        let sent = try await client.sendMessage(
            chatId: chatID,
            inputMessageContent: .inputMessageText(
                InputMessageText(
                    clearDraft: true,
                    linkPreviewOptions: nil,
                    text: FormattedText(entities: [], text: text)
                )
            ),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )

        guard let message = try await map(message: sent) else {
            throw TelegramClientError.chatNotFound
        }
        return message
    }

    private func ensureInitialized() async throws {
        switch currentTDLibState {
        case .authorizationStateWaitTdlibParameters:
            try await configureTDLib()
            try await refreshAuthorizationState()
        case .authorizationStateClosed, .authorizationStateClosing:
            rebuildClient()
            try await configureTDLib()
            try await refreshAuthorizationState()
        default:
            if case .waitingForPhoneNumber = state, currentTDLibState == .authorizationStateWaitTdlibParameters {
                try await configureTDLib()
                try await refreshAuthorizationState()
            } else if currentTDLibState == .authorizationStateWaitTdlibParameters {
                try await configureTDLib()
                try await refreshAuthorizationState()
            }
        }
    }

    private func ensureAuthorized() async throws {
        try await ensureInitialized()
        if currentTDLibState != .authorizationStateReady {
            try await refreshAuthorizationState()
        }
        guard case .ready = state else {
            throw TelegramClientError.unauthorized
        }
    }

    private func refreshAuthorizationState() async throws {
        let tdState = try await client.getAuthorizationState()
        currentTDLibState = tdState
        state = map(authorizationState: tdState)
        if case .ready = state {
            currentTelegramUser = try? await fetchCurrentUser()
        }
    }

    private func configureTDLib() async throws {
        let directories = try makeDirectories()
        try await client.setTdlibParameters(
            apiHash: configuration.apiHash,
            apiId: configuration.apiID,
            applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            databaseDirectory: directories.databaseDirectory.path,
            databaseEncryptionKey: nil,
            deviceModel: "iPhone",
            filesDirectory: directories.filesDirectory.path,
            systemLanguageCode: Locale.current.language.languageCode?.identifier ?? Locale.current.identifier,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            useChatInfoDatabase: true,
            useFileDatabase: true,
            useMessageDatabase: true,
            useSecretChats: true,
            useTestDc: configuration.useTestDC
        )
    }

    private func fetchCurrentUser() async throws -> TelegramUser {
        let me = try await client.getMe()
        cachedUsers[me.id] = me
        return TelegramUser(
            id: me.id,
            displayName: Self.displayName(firstName: me.firstName, lastName: me.lastName),
            phoneNumber: me.phoneNumber
        )
    }

    private func map(authorizationState: AuthorizationState) -> TelegramAuthorizationState {
        switch authorizationState {
        case .authorizationStateWaitTdlibParameters, .authorizationStateWaitPhoneNumber, .authorizationStateWaitOtherDeviceConfirmation, .authorizationStateWaitRegistration:
            return .waitingForPhoneNumber
        case .authorizationStateWaitCode:
            let phoneNumber = currentTelegramUser?.phoneNumber ?? ""
            return .waitingForCode(phoneNumber: phoneNumber)
        case .authorizationStateWaitPassword(let passwordState):
            let phoneNumber = currentTelegramUser?.phoneNumber ?? ""
            let hint = passwordState.passwordHint.isEmpty ? nil : passwordState.passwordHint
            return .waitingForPassword(phoneNumber: phoneNumber, hint: hint)
        case .authorizationStateReady:
            return .ready
        case .authorizationStateLoggingOut, .authorizationStateClosing, .authorizationStateClosed:
            return .loggingOut
        case .authorizationStateWaitPremiumPurchase, .authorizationStateWaitEmailAddress, .authorizationStateWaitEmailCode:
            return .waitingForPhoneNumber
        }
    }

    private func map(chat: TDLibKit.Chat) -> Chat {
        Chat(
            id: chat.id,
            title: chat.title,
            type: map(chatType: chat.type),
            lastMessageSnippet: messageSnippet(from: chat.lastMessage?.content),
            lastMessageDate: date(fromUnixTimestamp: chat.lastMessage?.date),
            unreadCount: chat.unreadCount
        )
    }

    private func map(chatType: TDLibKit.ChatType) -> Chat.ChatType {
        switch chatType {
        case .chatTypePrivate, .chatTypeSecret:
            return .private
        case .chatTypeBasicGroup:
            return .group
        case .chatTypeSupergroup(let supergroup):
            return supergroup.isChannel ? .channel : .supergroup
        }
    }

    private func map(message tdMessage: TDLibKit.Message) async throws -> Message? {
        guard let text = extractText(from: tdMessage.content) else {
            return nil
        }

        let senderName = try await senderName(for: tdMessage)
        return Message(
            id: tdMessage.id,
            chatID: tdMessage.chatId,
            senderName: senderName,
            originalText: text,
            date: date(fromUnixTimestamp: tdMessage.date) ?? Foundation.Date(),
            isOutgoing: tdMessage.isOutgoing
        )
    }

    private func extractText(from content: MessageContent) -> String? {
        switch content {
        case .messageText(let messageText):
            return messageText.text.text
        default:
            return nil
        }
    }

    private func senderName(for message: TDLibKit.Message) async throws -> String {
        switch message.senderId {
        case .messageSenderUser(let sender):
            if let user = cachedUsers[sender.userId] {
                return Self.displayName(firstName: user.firstName, lastName: user.lastName)
            }
            let user = try await client.getUser(userId: sender.userId)
            cachedUsers[user.id] = user
            return Self.displayName(firstName: user.firstName, lastName: user.lastName)
        case .messageSenderChat(let sender):
            if let chat = cachedChats[sender.chatId] {
                return chat.title
            }
            let chat = try await client.getChat(chatId: sender.chatId)
            cachedChats[chat.id] = chat
            return chat.title
        }
    }

    private func messageSnippet(from content: MessageContent?) -> String? {
        guard let content else { return nil }
        switch content {
        case .messageText(let messageText):
            return messageText.text.text
        case .messagePhoto(let messagePhoto):
            return messagePhoto.caption.text.isEmpty ? "Photo" : messagePhoto.caption.text
        case .messageVideo(let messageVideo):
            return messageVideo.caption.text.isEmpty ? "Video" : messageVideo.caption.text
        case .messageDocument(let messageDocument):
            return messageDocument.caption.text.isEmpty ? messageDocument.document.fileName : messageDocument.caption.text
        case .messageSticker(let sticker):
            return sticker.sticker.emoji.isEmpty ? "Sticker" : sticker.sticker.emoji
        default:
            return "Unsupported message"
        }
    }

    private func makeDirectories() throws -> (databaseDirectory: URL, filesDirectory: URL) {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("BZGram", isDirectory: true)

        let databaseDirectory = base.appendingPathComponent("tdlib-db", isDirectory: true)
        let filesDirectory = base.appendingPathComponent("tdlib-files", isDirectory: true)

        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)

        return (databaseDirectory, filesDirectory)
    }

    private func rebuildClient() {
        client = Self.manager.createClient(updateHandler: { _, _ in })
        currentTDLibState = .authorizationStateWaitTdlibParameters
    }

    private func map(error: Swift.Error) -> TelegramClientError {
        if let tdError = error as? TDLibKit.Error {
            let message = tdError.message.lowercased()
            if tdError.code == 400, message.contains("phone") {
                return .invalidPhoneNumber
            }
            if tdError.code == 400, message.contains("code") {
                return .invalidCode
            }
            if tdError.code == 400, message.contains("password") {
                return .invalidPassword
            }
        }
        return .unauthorized
    }

    private func date(fromUnixTimestamp timestamp: Int?) -> Foundation.Date? {
        guard let timestamp, timestamp > 0 else { return nil }
        return Foundation.Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func displayName(firstName: String, lastName: String) -> String {
        let joined = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return joined.isEmpty ? "Telegram User" : joined
    }

    public static func normalizePhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        guard !cleaned.isEmpty else { return "" }
        return cleaned.hasPrefix("+") ? cleaned : "+\(cleaned)"
    }
}
