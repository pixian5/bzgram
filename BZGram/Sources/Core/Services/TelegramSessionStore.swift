import Foundation
#if canImport(Combine)
import Combine
#endif

/// 中心化的 Telegram 会话状态管理器。
/// 管理认证状态、聊天数据、消息数据及所有通信操作。
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
        client: TelegramClient = MockTelegramClient(),
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
        }
    }

    public func loadMessages(for chatID: Int64) async {
        await perform { [self] in
            self.messagesByChatID[chatID] = try await self.client.fetchMessages(in: chatID)
        }
    }

    public func sendMessage(_ text: String, to chatID: Int64) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await perform { [self] in
            _ = try await self.client.sendMessage(trimmed, to: chatID)
            self.messagesByChatID[chatID] = try await self.client.fetchMessages(in: chatID)
            self.chats = try await self.client.fetchChats()
        }
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

    // MARK: - Toast

    public func showToast(_ message: String) {
        toastMessage = message
        // 2秒后自动清除
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
