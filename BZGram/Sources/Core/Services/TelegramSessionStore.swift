import Foundation
#if canImport(Combine)
import Combine
#endif

/// Central app session state for Telegram authorization and chat data.
@MainActor
public final class TelegramSessionStore: ObservableObject {

    @Published public private(set) var authorizationState: TelegramAuthorizationState = .waitingForPhoneNumber
    @Published public private(set) var currentUser: TelegramUser?
    @Published public private(set) var chats: [Chat] = []
    @Published public private(set) var messagesByChatID: [Int64: [Message]] = [:]
    @Published public private(set) var isBusy: Bool = false
    @Published public var lastErrorMessage: String?

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
