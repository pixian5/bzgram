import Foundation
#if canImport(Combine)
import Combine

/// Manages a pool of per-account `TelegramSessionStore` instances.
///
/// BZGram supports an unlimited number of Telegram accounts.  Each account gets its
/// own `TelegramSessionStore` backed by an isolated `TDLibTelegramClient` (separate
/// on-disk TDLib database), so sessions never interfere with one another.
///
/// `MultiAccountSessionManager` is the single source of truth for the active session.
/// UI code should observe this object and read `activeSession` whenever it needs the
/// current account's session store.
///
/// Changes to the *active session's* own state (e.g. `isAuthorized`) are forwarded
/// via `objectWillChange` so that SwiftUI views that observe this manager automatically
/// re-render when the active session's authorization state changes.
@MainActor
public final class MultiAccountSessionManager: ObservableObject {

    // MARK: - Published state

    /// The session store for the currently active account.
    /// `nil` only when no accounts have been added yet.
    @Published public private(set) var activeSession: TelegramSessionStore?

    // MARK: - Dependencies

    public let accountManager: AccountManager
    private let bundle: Bundle

    // MARK: - Private

    private var sessions: [UUID: TelegramSessionStore] = [:]
    /// Subscription that forwards the active session's objectWillChange to this manager
    /// so that SwiftUI views re-render when authorization state changes.
    private var activeSessionCancellable: AnyCancellable?

    // MARK: - Init

    public init(accountManager: AccountManager, bundle: Bundle = .main) {
        self.accountManager = accountManager
        self.bundle = bundle

        // Restore sessions for accounts that were persisted from a previous launch.
        for account in accountManager.accounts {
            sessions[account.id] = makeSession(for: account)
        }

        if let active = accountManager.activeAccount {
            let session = sessions[active.id]
            activeSession = session
            observeActiveSession(session)
        }
    }

    // MARK: - Account lifecycle

    /// Add a new account and create a dedicated session for it.
    ///
    /// The new account is automatically made active if it is the first account added.
    /// Returns the newly created `Account`.
    @discardableResult
    public func addAccount(displayName: String, phoneNumber: String) -> Account {
        let account = accountManager.addAccount(displayName: displayName, phoneNumber: phoneNumber)
        let newSession = makeSession(for: account)
        sessions[account.id] = newSession
        if activeSession == nil {
            activeSession = newSession
            observeActiveSession(newSession)
        }
        return account
    }

    /// Switch to the session belonging to `account`.
    public func switchToAccount(_ account: Account) {
        accountManager.setActive(account)
        let newSession = session(for: account)
        activeSession = newSession
        observeActiveSession(newSession)
    }

    /// Log out the given account's session without removing the account entry.
    public func logoutAccount(_ account: Account) async {
        if let existingSession = sessions[account.id] {
            await existingSession.logOut()
        }
        accountManager.logout(account.id)
    }

    /// Permanently remove an account and destroy its session.
    public func removeAccount(_ account: Account) async {
        if let existingSession = sessions[account.id] {
            await existingSession.logOut()
        }
        sessions.removeValue(forKey: account.id)
        accountManager.removeAccount(account.id)

        // Point the active session at whatever account the manager fell back to.
        if let newActive = accountManager.activeAccount {
            let newSession = sessions[newActive.id]
            activeSession = newSession
            observeActiveSession(newSession)
        } else {
            activeSession = nil
            activeSessionCancellable = nil
        }
    }

    // MARK: - Session access

    /// Returns the session store for the given account, creating one if necessary.
    public func session(for account: Account) -> TelegramSessionStore {
        if let existing = sessions[account.id] { return existing }
        let newSession = makeSession(for: account)
        sessions[account.id] = newSession
        return newSession
    }

    // MARK: - Private helpers

    private func makeSession(for account: Account) -> TelegramSessionStore {
        let client = TelegramClientFactory.makeClient(for: account, bundle: bundle)
        return TelegramSessionStore(client: client, accountManager: accountManager)
    }

    /// Forward the active session's objectWillChange to this manager so SwiftUI views
    /// that observe `MultiAccountSessionManager` re-render when authorization state changes.
    private func observeActiveSession(_ session: TelegramSessionStore?) {
        activeSessionCancellable = session?
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }
}
#endif
