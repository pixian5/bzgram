import Foundation
#if canImport(Combine)
import Combine
#endif

/// 中心化的 Telegram 会话状态管理器。
/// 管理认证状态、聊天数据、消息数据及所有通信操作。
/// 同时实现 TelegramUpdateDelegate 接收 TDLib 实时推送。
@MainActor
public final class TelegramSessionStore: ObservableObject {

    @Published public private(set) var authorizationState: TelegramAuthorizationState = .waitingForPhoneNumber
    @Published public private(set) var currentUser: TelegramUser?
    @Published public private(set) var chats: [Chat] = []
    @Published public private(set) var messagesByChatID: [Int64: [Message]] = [:]
    @Published public private(set) var isBusy: Bool = false
    @Published public var lastErrorMessage: String?
    /// Toast 提示消息
    @Published public var toastMessage: String?

    private let client: TelegramClient
    private let accountManager: AccountManager

    public init(
        client: TelegramClient,
        accountManager: AccountManager
    ) {
        self.client = client
        self.accountManager = accountManager
    }

    public var isAuthorized: Bool {
        authorizationState == .ready
    }

    // MARK: - 认证流程

    public func start() async {
        // 注册实时更新委托
        await client.setUpdateDelegate(self)
        authorizationState = await client.authorizationState()
        currentUser = await client.currentUser()
        if isAuthorized {
            syncAuthorizedAccount()
            await refreshChats()
        }
    }

    public func submitPhoneNumber(_ phoneNumber: String) async {
        await perform { [self] in
            self.authorizationState = try await self.client.submitPhoneNumber(phoneNumber)
        }
    }

    public func submitCode(_ code: String) async {
        await perform { [self] in
            self.authorizationState = try await self.client.submitCode(code)
            self.currentUser = await self.client.currentUser()
            self.syncAuthorizedAccount()
            await self.refreshChats()
        }
    }

    public func submitPassword(_ password: String) async {
        await perform { [self] in
            self.authorizationState = try await self.client.submitPassword(password)
            self.currentUser = await self.client.currentUser()
            self.syncAuthorizedAccount()
            await self.refreshChats()
        }
    }

    public func logOut() async {
        isBusy = true
        lastErrorMessage = nil
        authorizationState = await client.logOut()
        currentUser = nil
        chats = []
        messagesByChatID = [:]
        if let active = accountManager.activeAccount {
            accountManager.logout(active.id)
        }
        isBusy = false
    }

    // MARK: - 聊天操作

    public func refreshChats() async {
        await perform { [self] in
            self.chats = try await self.client.fetchChats()
            self.sortChats()
        }
    }

    public func loadMessages(for chatID: Int64) async {
        await perform { [self] in
            self.messagesByChatID[chatID] = try await self.client.fetchMessages(in: chatID)
        }
    }

    /// 发送消息，带状态反馈（sending → sent / failed）
    public func sendMessage(_ text: String, to chatID: Int64) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. 立即插入一条"发送中"的占位消息，让 UI 即时反馈
        let pendingID = -Int64(Date().timeIntervalSince1970 * 1000)
        let pendingMessage = Message(
            id: pendingID,
            chatID: chatID,
            senderName: currentUser?.displayName ?? "Me",
            originalText: trimmed,
            date: Date(),
            isOutgoing: true,
            canBeEdited: true,
            sendStatus: .sending
        )
        messagesByChatID[chatID, default: []].append(pendingMessage)

        // 2. 调用 TDLib 发送
        do {
            let sent = try await client.sendMessage(trimmed, to: chatID)
            // 3. 成功：用真实消息替换占位消息
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index] = sent
            }
            // 刷新聊天列表以更新最后消息
            chats = try await client.fetchChats()
            sortChats()
        } catch {
            // 4. 失败：标记占位消息为"发送失败"
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index].sendStatus = .failed
            }
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func sendPhoto(filePath: String, caption: String, to chatID: Int64) async {
        let pendingID = -Int64(Date().timeIntervalSince1970 * 1000)
        let pendingMessage = Message(
            id: pendingID,
            chatID: chatID,
            senderName: currentUser?.displayName ?? "Me",
            originalText: caption,
            date: Date(),
            isOutgoing: true,
            contentType: .photo,
            canBeEdited: true,
            sendStatus: .sending
        )
        messagesByChatID[chatID, default: []].append(pendingMessage)

        do {
            let sent = try await client.sendPhoto(filePath: filePath, caption: caption, to: chatID)
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index] = sent
            }
            chats = try await client.fetchChats()
            sortChats()
        } catch {
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index].sendStatus = .failed
            }
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func sendVideo(filePath: String, caption: String, to chatID: Int64) async {
        let pendingID = -Int64(Date().timeIntervalSince1970 * 1000)
        let pendingMessage = Message(
            id: pendingID,
            chatID: chatID,
            senderName: currentUser?.displayName ?? "Me",
            originalText: caption,
            date: Date(),
            isOutgoing: true,
            contentType: .video,
            canBeEdited: true,
            sendStatus: .sending
        )
        messagesByChatID[chatID, default: []].append(pendingMessage)

        do {
            let sent = try await client.sendVideo(filePath: filePath, caption: caption, to: chatID)
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index] = sent
            }
            chats = try await client.fetchChats()
            sortChats()
        } catch {
            if let index = messagesByChatID[chatID]?.firstIndex(where: { $0.id == pendingID }) {
                messagesByChatID[chatID]?[index].sendStatus = .failed
            }
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 重试发送失败的消息
    public func retryMessage(_ message: Message) async {
        // 移除失败的占位消息
        messagesByChatID[message.chatID]?.removeAll { $0.id == message.id }
        // 重新发送
        await sendMessage(message.originalText, to: message.chatID)
    }

    public func messages(for chatID: Int64) -> [Message] {
        messagesByChatID[chatID] ?? []
    }

    // MARK: - 增强操作

    /// 编辑消息
    public func editMessage(messageID: Int64, in chatID: Int64, newText: String) async {
        await perform { [self] in
            try await self.client.editMessage(messageID: messageID, in: chatID, newText: newText)
            self.messagesByChatID[chatID] = try await self.client.fetchMessages(in: chatID)
            self.showToast("消息已编辑")
        }
    }

    /// 删除/撤回消息
    public func deleteMessage(messageID: Int64, in chatID: Int64) async {
        await perform { [self] in
            try await self.client.deleteMessages(messageIDs: [messageID], in: chatID)
            self.messagesByChatID[chatID]?.removeAll { $0.id == messageID }
            self.showToast("消息已撤回")
        }
    }

    /// 标记会话已读
    public func markAsRead(chatID: Int64) async {
        await perform { [self] in
            try await self.client.markChatAsRead(chatID: chatID)
            if let index = self.chats.firstIndex(where: { $0.id == chatID }) {
                self.chats[index].unreadCount = 0
            }
        }
    }

    public func viewMessages(chatID: Int64, messageIDs: [Int64], forceRead: Bool = true) async {
        guard !messageIDs.isEmpty else { return }
        await perform { [self] in
            try await self.client.viewMessages(chatID: chatID, messageIDs: messageIDs, forceRead: forceRead)
            if forceRead {
                if let index = self.chats.firstIndex(where: { $0.id == chatID }) {
                    // This is a naive way to clear unread, ideally TDLib pushes unread count updates.
                    self.chats[index].unreadCount = 0
                }
            }
        }
    }

    public func sendTypingAction(chatID: Int64, action: String) async {
        await perform { [self] in
            try await self.client.sendTypingAction(chatID: chatID, action: action)
        }
    }

    /// 置顶/取消置顶会话
    public func togglePin(for chatID: Int64) async {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].isPinned.toggle()
            sortChats()
            showToast(chats[index].isPinned ? "已置顶" : "已取消置顶")
        }
    }

    /// 静音/取消静音会话
    public func toggleMute(for chatID: Int64) async {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].isMuted.toggle()
            showToast(chats[index].isMuted ? "已静音" : "已取消静音")
        }
    }

    /// 删除会话
    public func deleteChat(chatID: Int64) async {
        chats.removeAll { $0.id == chatID }
        messagesByChatID.removeValue(forKey: chatID)
    }

    // MARK: - 搜索（委托给 TDLib 服务端）

    /// 服务端搜索消息，避免内存中遍历全量消息导致性能问题
    public func searchMessages(query: String, in chatID: Int64, limit: Int = 50) async -> [Message] {
        guard !query.isEmpty else { return messages(for: chatID) }
        do {
            return try await client.searchMessages(query: query, in: chatID, limit: limit)
        } catch {
            // 搜索失败时回退到本地过滤（仅过滤已加载的消息）
            return messages(for: chatID).filter {
                $0.originalText.localizedCaseInsensitiveContains(query)
            }
        }
    }

    // MARK: - Toast

    public func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }

    // MARK: - Private

    private func perform(_ operation: @escaping () async throws -> Void) async {
        isBusy = true
        lastErrorMessage = nil
        do {
            try await operation()
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isBusy = false
    }

    /// 排序聊天列表：置顶优先 → 最近消息时间倒序
    private func sortChats() {
        chats.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            let lhsDate = lhs.lastMessageDate ?? .distantPast
            let rhsDate = rhs.lastMessageDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private func syncAuthorizedAccount() {
        guard let user = currentUser else { return }

        if let existing = accountManager.accounts.first(where: { $0.telegramUserID == user.id }) {
            accountManager.markAuthenticated(existing.id, telegramUserID: user.id, displayName: user.displayName)
            if let refreshed = accountManager.accounts.first(where: { $0.id == existing.id }) {
                accountManager.setActive(refreshed)
            }
            return
        }

        let newAccount = accountManager.addAccount(
            displayName: user.displayName,
            phoneNumber: user.phoneNumber
        )
        accountManager.markAuthenticated(
            newAccount.id,
            telegramUserID: user.id,
            displayName: user.displayName
        )
        if let refreshed = accountManager.accounts.first(where: { $0.id == newAccount.id }) {
            accountManager.setActive(refreshed)
        }
    }
}

// MARK: - TelegramUpdateDelegate

extension TelegramSessionStore: TelegramUpdateDelegate {

    /// 收到新消息 → 自动插入到对应聊天的消息列表
    public nonisolated func didReceiveNewMessage(_ message: Message) {
        Task { @MainActor in
            self.messagesByChatID[message.chatID, default: []].append(message)
        }
    }

    /// 聊天信息更新（最后消息变更等）→ 更新聊天列表
    public nonisolated func didUpdateChat(_ chat: Chat) {
        Task { @MainActor in
            if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
                // 保留本地状态（置顶、静音等）
                var updated = chat
                updated.isPinned = self.chats[index].isPinned
                updated.isMuted = self.chats[index].isMuted
                self.chats[index] = updated
            } else {
                self.chats.append(chat)
            }
            self.sortChats()
        }
    }

    /// 未读计数变更 → 同步更新本地聊天的 unreadCount
    public nonisolated func didUpdateUnreadCount(chatID: Int64, unreadCount: Int) {
        Task { @MainActor in
            if let index = self.chats.firstIndex(where: { $0.id == chatID }) {
                self.chats[index].unreadCount = unreadCount
            }
        }
    }

    /// 消息内容被编辑 → 更新本地消息
    public nonisolated func didUpdateMessageContent(chatID: Int64, messageID: Int64, newText: String) {
        Task { @MainActor in
            if let index = self.messagesByChatID[chatID]?.firstIndex(where: { $0.id == messageID }) {
                // Message 是 struct，需要重新构造（只改 originalText 和 isEdited）
                var msg = self.messagesByChatID[chatID]![index]
                msg = Message(
                    id: msg.id, chatID: msg.chatID, senderName: msg.senderName,
                    senderUserID: msg.senderUserID, originalText: newText,
                    translatedText: nil, date: msg.date, isOutgoing: msg.isOutgoing,
                    contentType: msg.contentType, attachment: msg.attachment,
                    isEdited: true, replyToMessageId: msg.replyToMessageId,
                    canBeDeleted: msg.canBeDeleted, canBeEdited: msg.canBeEdited,
                    sendStatus: msg.sendStatus
                )
                self.messagesByChatID[chatID]![index] = msg
            }
        }
    }

    /// 消息被删除 → 从本地列表移除
    public nonisolated func didDeleteMessages(chatID: Int64, messageIDs: [Int64]) {
        Task { @MainActor in
            self.messagesByChatID[chatID]?.removeAll { messageIDs.contains($0.id) }
        }
    }
}
