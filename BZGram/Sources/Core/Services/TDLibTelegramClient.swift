import Foundation
@preconcurrency import TDLibKit

public actor TDLibTelegramClient: TelegramClient {

    private static let manager = TDLibClientManager()

    private let configuration: TelegramAPIConfiguration
    /// 实例标识，用于隔离不同账号的 TDLib 数据目录
    private let instanceId: String
    private var client: TDLibClient
    private var state: TelegramAuthorizationState = .waitingForPhoneNumber
    private var currentTDLibState: AuthorizationState = .authorizationStateWaitTdlibParameters
    private var currentTelegramUser: TelegramUser?
    private var cachedUsers: [Int64: User] = [:]
    private var cachedChats: [Int64: TDLibKit.Chat] = [:]
    private var cachedFolders: [ChatFolder] = []
    /// 临时保存正在登录的手机号
    private var pendingPhoneNumber: String?
    /// 实时更新委托
    private weak var updateDelegate: TelegramUpdateDelegate?
    private let updateHandlerRef: TDLibUpdateHandlerRef

    public init(configuration: TelegramAPIConfiguration, instanceId: String = "default") {
        self.configuration = configuration
        self.instanceId = instanceId
        
        // 在初始化时就定死 updateHandler，避免后续重建客户端导致文件锁死
        let weakRef = TDLibUpdateHandlerRef()
        self.client = Self.manager.createClient { data, client in
            Task {
                await weakRef.handler?(data)
            }
        }
        self.updateHandlerRef = weakRef
        weakRef.handler = { [weak self] data in
            await self?.handleUpdate(data)
        }
    }

    public func setUpdateDelegate(_ delegate: TelegramUpdateDelegate?) {
        self.updateDelegate = delegate
    }

    private class TDLibUpdateHandlerRef {
        var handler: ((Data) async -> Void)?
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
        self.pendingPhoneNumber = normalizedPhoneNumber

        try await ensureInitialized()
        print("📲 [BZGram] 开始提交手机号验证请求: \(normalizedPhoneNumber)")
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

    public func resendAuthenticationCode() async throws -> TelegramAuthorizationState {
        try await ensureInitialized()
        _ = try await client.resendAuthenticationCode(reason: nil)
        try await refreshAuthorizationState()
        return state
    }

    public func submitCode(_ code: String) async throws -> TelegramAuthorizationState {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TelegramClientError.invalidCode
        }

        try await ensureInitialized()
        // checkAuthenticationCode 即使返回 error，TDLib 也可能已经推进了授权状态
        // （例如验证码错误时返回 WaitCode 带新倒计时，或错误时跳到 WaitPassword）
        _ = try? await client.checkAuthenticationCode(code: trimmed)
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
        
        // 采用与 submitCode 相同的逻辑：忽略直接报错，通过 refreshAuthorizationState 捕获真实状态
        // 解决密码正确却提示不正确的问题
        _ = try? await client.checkAuthenticationPassword(password: trimmed)
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
        cachedFolders = []
        rebuildClient()
        state = .waitingForPhoneNumber
        currentTDLibState = .authorizationStateWaitTdlibParameters
        return state
    }

    public func fetchFolders() async throws -> [ChatFolder] {
        try await ensureAuthorized()
        if cachedFolders.isEmpty {
            _ = try? await client.loadChats(chatList: .chatListMain, limit: 1)
            for _ in 0..<10 where cachedFolders.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        return cachedFolders
    }

    public func fetchContacts() async throws -> [Contact] {
        try await ensureAuthorized()
        let usersInfo = try await client.getContacts()
        var contacts = [Contact]()
        contacts.reserveCapacity(usersInfo.userIds.count)

        for userId in usersInfo.userIds {
            if let user = try? await client.getUser(userId: userId) {
                contacts.append(map(user: user))
            }
        }
        return contacts
    }

    private func map(user: TDLibKit.User) -> Contact {
        let displayName = [user.firstName, user.lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let status: Contact.OnlineStatus
        switch user.status {
        case .userStatusOnline: status = .online
        case .userStatusOffline: status = .offline
        case .userStatusRecently: status = .recently
        case .userStatusLastWeek: status = .lastWeek
        case .userStatusLastMonth: status = .lastMonth
        case .userStatusEmpty: status = .unknown
        }

        return Contact(
            id: user.id,
            displayName: displayName.isEmpty ? "Unknown" : displayName,
            username: user.usernames?.activeUsernames.first,
            phoneNumber: user.phoneNumber.isEmpty ? nil : user.phoneNumber,
            status: status,
            isMutualContact: user.isMutualContact
        )
    }

    public func fetchChats(folderId: Int? = nil) async throws -> [Chat] {
        try await ensureAuthorized()

        let chatList: TDLibKit.ChatList
        if let id = folderId {
            chatList = .chatListFolder(TDLibKit.ChatListFolder(chatFolderId: id))
        } else {
            chatList = .chatListMain
        }
        
        // 核心修复：必须调用 loadChats 触发 TDLib 从服务器同步对话列表和文件夹
        _ = try? await client.loadChats(chatList: chatList, limit: 100)

        let ids = try await client.getChats(chatList: chatList, limit: 100).chatIds
        var chats: [Chat] = []
        chats.reserveCapacity(ids.count)

        for chatID in ids {
            let tdChat = try await client.getChat(chatId: chatID)
            cachedChats[chatID] = tdChat
            chats.append(map(chat: tdChat, in: chatList))
        }

        return chats.sorted { lhs, rhs in
            let lhsPosition = position(for: lhs.id, in: chatList)
            let rhsPosition = position(for: rhs.id, in: chatList)
            let lhsOrder = lhsPosition?.order ?? 0
            let rhsOrder = rhsPosition?.order ?? 0
            if lhsOrder != rhsOrder { return lhsOrder > rhsOrder }
            return lhs.id > rhs.id
        }
    }

    public func fetchMessages(in chatID: Int64) async throws -> [Message] {
        try await ensureAuthorized()

        print("🚀 [BZGram] fetchMessages for chatID: \(chatID)")
        // 必须先 openChat，TDLib 才会为超级群组/频道返回完整历史
        do {
            _ = try await client.openChat(chatId: chatID)
        } catch {
            print("❌ [BZGram] openChat error: \(error)")
        }

        var tdMessages = await loadHistory(chatID: chatID, fromMessageId: 0)
        print("🚀 [BZGram] getChatHistory returned \(tdMessages.count) messages")

        if tdMessages.isEmpty,
           let chat = try? await client.getChat(chatId: chatID),
           let lastMessage = chat.lastMessage {
            cachedChats[chat.id] = chat
            tdMessages = await loadHistory(chatID: chatID, fromMessageId: lastMessage.id)
            print("🚀 [BZGram] getChatHistory from lastMessage returned \(tdMessages.count) messages")
        }

        if tdMessages.isEmpty, let fallback = await fallbackLastMessage(in: chatID) {
            print("⚠️ [BZGram] History empty; using last message fallback")
            return [fallback]
        }
        
        var mapped: [Message] = []
        mapped.reserveCapacity(tdMessages.count)
        for tdMessage in tdMessages {
            if let message = await map(message: tdMessage) {
                mapped.append(message)
            } else {
                print("⚠️ [BZGram] Failed to map message: \(tdMessage)")
            }
        }

        if mapped.isEmpty, let fallback = await fallbackLastMessage(in: chatID) {
            print("⚠️ [BZGram] No mapped history messages; using last message fallback")
            return [fallback]
        }

        print("🚀 [BZGram] successfully mapped \(mapped.count) messages")
        return mapped.sorted { $0.date < $1.date }
    }

    public func searchMessages(query: String, in chatID: Int64, limit: Int) async throws -> [Message] {
        try await ensureAuthorized()

        let results = try await client.searchChatMessages(
            chatId: chatID,
            filter: nil,
            fromMessageId: 0,
            limit: limit,
            offset: 0,
            query: query,
            senderId: nil,
            topicId: nil
        )

        let tdMessages = results.messages
        var mapped: [Message] = []
        mapped.reserveCapacity(tdMessages.count)
        for tdMessage in tdMessages {
            if let message = await map(message: tdMessage) {
                mapped.append(message)
            }
        }
        return mapped
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

        guard let message = await map(message: sent) else {
            throw TelegramClientError.chatNotFound
        }
        return message
    }

    public func sendPhoto(filePath: String, caption: String, to chatID: Int64) async throws -> Message {
        try await ensureAuthorized()
        let sent = try await client.sendMessage(
            chatId: chatID,
            inputMessageContent: .inputMessagePhoto(
                InputMessagePhoto(
                    addedStickerFileIds: [],
                    caption: FormattedText(entities: [], text: caption),
                    hasSpoiler: false,
                    height: 0,
                    photo: .inputFileLocal(InputFileLocal(path: filePath)),
                    selfDestructType: nil,
                    showCaptionAboveMedia: false,
                    thumbnail: nil,
                    video: nil,
                    width: 0
                )
            ),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
        guard let message = await map(message: sent) else {
            throw TelegramClientError.chatNotFound
        }
        return message
    }

    public func sendVideo(filePath: String, caption: String, to chatID: Int64) async throws -> Message {
        try await ensureAuthorized()
        let sent = try await client.sendMessage(
            chatId: chatID,
            inputMessageContent: .inputMessageVideo(
                InputMessageVideo(
                    addedStickerFileIds: [],
                    caption: FormattedText(entities: [], text: caption),
                    cover: nil,
                    duration: 0,
                    hasSpoiler: false,
                    height: 0,
                    selfDestructType: nil,
                    showCaptionAboveMedia: false,
                    startTimestamp: 0,
                    supportsStreaming: false,
                    thumbnail: nil,
                    video: .inputFileLocal(InputFileLocal(path: filePath)),
                    width: 0
                )
            ),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
        guard let message = await map(message: sent) else {
            throw TelegramClientError.chatNotFound
        }
        return message
    }

    public func viewMessages(chatID: Int64, messageIDs: [Int64], forceRead: Bool) async throws {
        try await ensureAuthorized()
        _ = try await client.viewMessages(chatId: chatID, forceRead: forceRead, messageIds: messageIDs, source: nil)
    }

    public func sendTypingAction(chatID: Int64, action: String) async throws {
        try await ensureAuthorized()
        let chatAction: ChatAction
        if action == "typing" {
            chatAction = .chatActionTyping
        } else if action == "upload_photo" {
            chatAction = .chatActionUploadingPhoto(ChatActionUploadingPhoto(progress: 0))
        } else if action == "upload_video" {
            chatAction = .chatActionUploadingVideo(ChatActionUploadingVideo(progress: 0))
        } else {
            chatAction = .chatActionTyping
        }
        _ = try await client.sendChatAction(action: chatAction, businessConnectionId: nil, chatId: chatID, topicId: nil)
    }

    public func pinMessage(messageID: Int64, in chatID: Int64) async throws {
        try await ensureAuthorized()
        _ = try await client.pinChatMessage(chatId: chatID, disableNotification: false, messageId: messageID, onlyForSelf: false)
    }

    public func unpinMessage(messageID: Int64, in chatID: Int64) async throws {
        try await ensureAuthorized()
        _ = try await client.unpinChatMessage(chatId: chatID, messageId: messageID)
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
        print("🛠 [BZGram] 正在配置 TDLib 参数，API ID: \(configuration.apiID)...")
        print("🛠 [BZGram] 数据库目录: \(directories.databaseDirectory.path)")
        
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
        print("✅ [BZGram] TDLib 参数配置成功！")
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
            // 修正：从关联值中获取状态，并确保手机号能正确传递
            let phoneNumber = pendingPhoneNumber ?? ""
            return .waitingForCode(phoneNumber: phoneNumber)
        case .authorizationStateWaitPassword(let passwordState):
            let phoneNumber = pendingPhoneNumber ?? ""
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

    private func map(chat: TDLibKit.Chat, in chatList: TDLibKit.ChatList = .chatListMain) -> Chat {
        let chatPosition = position(in: chat, matching: chatList)
        return Chat(
            id: chat.id,
            title: chat.title,
            type: map(chatType: chat.type),
            lastMessageSnippet: messageSnippet(from: chat.lastMessage?.content),
            lastMessageDate: date(fromUnixTimestamp: chat.lastMessage?.date),
            unreadCount: chat.unreadCount,
            isPinned: chatPosition?.isPinned ?? false,
            isMuted: chat.notificationSettings.muteFor > 0,
            isArchived: chat.chatLists.contains(.chatListArchive)
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

    private func map(message tdMessage: TDLibKit.Message) async -> Message? {
        let (text, contentType) = extractContent(from: tdMessage.content)

        let senderName = await senderName(for: tdMessage)
        return Message(
            id: tdMessage.id,
            chatID: tdMessage.chatId,
            senderName: senderName,
            originalText: text,
            date: date(fromUnixTimestamp: tdMessage.date) ?? Foundation.Date(),
            isOutgoing: tdMessage.isOutgoing,
            contentType: contentType
        )
    }

    private func extractContent(from content: MessageContent) -> (String, MessageContentType) {
        switch content {
        case .messageText(let messageText):
            return (messageText.text.text, .text)
        case .messagePhoto(let messagePhoto):
            return (messagePhoto.caption.text.isEmpty ? "[图片]" : messagePhoto.caption.text, .photo)
        case .messageVideo(let messageVideo):
            return (messageVideo.caption.text.isEmpty ? "[视频]" : messageVideo.caption.text, .video)
        case .messageDocument(let messageDocument):
            return (messageDocument.caption.text.isEmpty ? "[文件]" : messageDocument.caption.text, .document)
        case .messageSticker(let sticker):
            return (sticker.sticker.emoji.isEmpty ? "[贴纸]" : sticker.sticker.emoji, .sticker)
        case .messageVoiceNote:
            return ("[语音]", .voice)
        case .messageAnimation:
            return ("[GIF]", .animation)
        case .messageLocation:
            return ("[位置]", .location)
        case .messageContact:
            return ("[联系人]", .contact)
        default:
            return ("[未知消息]", .unsupported)
        }
    }

    private func senderName(for message: TDLibKit.Message) async -> String {
        switch message.senderId {
        case .messageSenderUser(let sender):
            if let user = cachedUsers[sender.userId] {
                return Self.displayName(firstName: user.firstName, lastName: user.lastName)
            }
            do {
                let user = try await client.getUser(userId: sender.userId)
                cachedUsers[user.id] = user
                return Self.displayName(firstName: user.firstName, lastName: user.lastName)
            } catch {
                print("⚠️ [BZGram] Failed to resolve sender user \(sender.userId): \(error)")
                return "User \(sender.userId)"
            }
        case .messageSenderChat(let sender):
            if let chat = cachedChats[sender.chatId] {
                return chat.title
            }
            do {
                let chat = try await client.getChat(chatId: sender.chatId)
                cachedChats[chat.id] = chat
                return chat.title
            } catch {
                print("⚠️ [BZGram] Failed to resolve sender chat \(sender.chatId): \(error)")
                return "Chat \(sender.chatId)"
            }
        }
    }

    private func fallbackLastMessage(in chatID: Int64) async -> Message? {
        guard let chat = try? await client.getChat(chatId: chatID),
              let lastMessage = chat.lastMessage else {
            return nil
        }
        cachedChats[chat.id] = chat
        if let fetched = try? await client.getMessage(chatId: chatID, messageId: lastMessage.id),
           let mapped = await map(message: fetched) {
            return mapped
        }
        return await map(message: lastMessage)
    }

    private func loadHistory(chatID: Int64, fromMessageId: Int64) async -> [TDLibKit.Message] {
        do {
            let history = try await client.getChatHistory(
                chatId: chatID,
                fromMessageId: fromMessageId,
                limit: 100,
                offset: 0,
                onlyLocal: false
            )
            return history.messages ?? []
        } catch {
            print("❌ [BZGram] getChatHistory error chatID=\(chatID), fromMessageId=\(fromMessageId): \(error)")
            return []
        }
    }

    private func position(for chatID: Int64, in chatList: TDLibKit.ChatList) -> TDLibKit.ChatPosition? {
        guard let chat = cachedChats[chatID] else { return nil }
        return position(in: chat, matching: chatList)
    }

    private func position(in chat: TDLibKit.Chat, matching chatList: TDLibKit.ChatList) -> TDLibKit.ChatPosition? {
        chat.positions.first { $0.list == chatList }
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
         .appendingPathComponent("accounts", isDirectory: true)
         .appendingPathComponent(instanceId, isDirectory: true)

        let databaseDirectory = base.appendingPathComponent("tdlib-db", isDirectory: true)
        let filesDirectory = base.appendingPathComponent("tdlib-files", isDirectory: true)

        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)

        return (databaseDirectory, filesDirectory)
    }

    private func rebuildClient() {
        client = Self.manager.createClient { [weak self] data, client in
            guard let self = self else { return }
            Task {
                await self.handleUpdate(data)
            }
        }
        currentTDLibState = .authorizationStateWaitTdlibParameters
    }

    // MARK: - TDLib 实时更新处理

    /// 处理 TDLib 服务器推送的实时更新
    private func handleUpdate(_ update: Data) {
        // 解析 TDLib 更新 JSON
        guard let json = try? JSONSerialization.jsonObject(with: update) as? [String: Any],
              let type = json["@type"] as? String else { return }

        switch type {
        case "updateAuthorizationState":
            // 核心修复：监听授权状态变更
            if let stateDict = json["authorization_state"] as? [String: Any],
               let stateData = try? JSONSerialization.data(withJSONObject: stateDict),
               let tdState = try? JSONDecoder().decode(AuthorizationState.self, from: stateData) {
                currentTDLibState = tdState
                let newState = map(authorizationState: tdState)
                self.state = newState
                if let delegate = updateDelegate {
                    Task { @MainActor in delegate.didUpdateAuthorizationState(newState) }
                }
            }

        case "updateChatFolders":
            print("📁 [BZGram] Received updateChatFolders: \(json)")
            if let folders = json["chat_folders"] as? [[String: Any]] {
                let parsedFolders = folders.compactMap { dict -> ChatFolder? in
                    guard let id = dict["id"] as? Int else { return nil }
                    // ChatFolderInfo.name 是 ChatFolderName 对象，其 text 是 FormattedText 对象
                    let nameObj = dict["name"] as? [String: Any]
                    let textObj = nameObj?["text"] as? [String: Any]
                    let title = textObj?["text"] as? String ?? "文件夹"
                    print("📁 [BZGram] Parsed folder: id=\(id), title=\(title)")
                    return ChatFolder(id: id, title: title)
                }
                cachedFolders = parsedFolders
                if let delegate = updateDelegate {
                    Task { @MainActor in delegate.didUpdateChatFolders(parsedFolders) }
                }
            }

        case "updateAuthenticationCode":
            // 收到验证码发送详情 (例如：短信已发送)
            print("📩 [BZGram] Received Authentication Code Update: \(json)")

        case "updateNewMessage":
            // 收到新消息
            guard let messageDict = json["message"] as? [String: Any],
                  let chatId = messageDict["chat_id"] as? Int64,
                  let messageId = messageDict["id"] as? Int64,
                  let date = messageDict["date"] as? Int,
                  let isOutgoing = messageDict["is_outgoing"] as? Bool else { return }

            let text = extractTextFromUpdate(messageDict)
            let senderName = extractSenderNameFromUpdate(messageDict)

            let message = Message(
                id: messageId,
                chatID: chatId,
                senderName: senderName,
                originalText: text,
                date: Foundation.Date(timeIntervalSince1970: TimeInterval(date)),
                isOutgoing: isOutgoing
            )
            if let delegate = updateDelegate {
                Task { @MainActor in delegate.didReceiveNewMessage(message) }
            }

        case "updateChatLastMessage":
            // 聊天的最后一条消息变更
            guard let chatId = json["chat_id"] as? Int64 else { return }
            if let tdChat = cachedChats[chatId] {
                let mapped = map(chat: tdChat)
                if let delegate = updateDelegate {
                    Task { @MainActor in delegate.didUpdateChat(mapped) }
                }
            }

        case "updateChatReadInbox":
            // 收件箱已读回执
            guard let chatId = json["chat_id"] as? Int64,
                  let unreadCount = json["unread_count"] as? Int else { return }
            if let delegate = updateDelegate {
                Task { @MainActor in delegate.didUpdateUnreadCount(chatID: chatId, unreadCount: unreadCount) }
            }

        case "updateMessageContent":
            // 消息内容被编辑
            guard let chatId = json["chat_id"] as? Int64,
                  let messageId = json["message_id"] as? Int64,
                  let newContent = json["new_content"] as? [String: Any],
                  let contentType = newContent["@type"] as? String,
                  contentType == "messageText",
                  let textObj = newContent["text"] as? [String: Any],
                  let newText = textObj["text"] as? String else { return }
            if let delegate = updateDelegate {
                Task { @MainActor in delegate.didUpdateMessageContent(chatID: chatId, messageID: messageId, newText: newText) }
            }

        case "updateDeleteMessages":
            // 消息被删除
            guard let chatId = json["chat_id"] as? Int64,
                  let messageIds = json["message_ids"] as? [Int64],
                  let isPermanent = json["is_permanent"] as? Bool,
                  isPermanent else { return }
            if let delegate = updateDelegate {
                Task { @MainActor in delegate.didDeleteMessages(chatID: chatId, messageIDs: messageIds) }
            }

        default:
            break
        }
    }

    private func extractTextFromUpdate(_ messageDict: [String: Any]) -> String {
        guard let content = messageDict["content"] as? [String: Any],
              let contentType = content["@type"] as? String else { return "" }
        switch contentType {
        case "messageText":
            return (content["text"] as? [String: Any])?["text"] as? String ?? ""
        case "messagePhoto":
            return (content["caption"] as? [String: Any])?["text"] as? String ?? "[图片]"
        case "messageVideo":
            return (content["caption"] as? [String: Any])?["text"] as? String ?? "[视频]"
        case "messageDocument":
            return (content["caption"] as? [String: Any])?["text"] as? String ?? "[文件]"
        default:
            return "[不支持的消息类型]"
        }
    }

    private func extractSenderNameFromUpdate(_ messageDict: [String: Any]) -> String {
        guard let senderId = messageDict["sender_id"] as? [String: Any] else { return "Unknown" }
        if let userId = senderId["user_id"] as? Int64 {
            if let user = cachedUsers[userId] {
                return Self.displayName(firstName: user.firstName, lastName: user.lastName)
            }
            return "User \(userId)"
        }
        if let chatId = senderId["chat_id"] as? Int64 {
            return cachedChats[chatId]?.title ?? "Chat \(chatId)"
        }
        return "Unknown"
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
            if tdError.code == 400, (message.contains("password") || message.contains("2fa")) {
                return .invalidPassword
            }
            return .unknown("TDLib Error \(tdError.code): \(tdError.message)")
        }
        return .unknown(error.localizedDescription)
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
