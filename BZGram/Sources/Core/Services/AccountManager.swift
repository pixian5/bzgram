import Foundation
#if canImport(Combine)
import Combine
#endif

/// Manages all Telegram accounts stored on the device.
///
/// BZGram imposes **no upper limit** on the number of simultaneous accounts.
/// Each account's state is persisted in `UserDefaults` (or a secure store in production).
public final class AccountManager {

    // MARK: - State

    /// All accounts known to the app, in the order they were added.
    public private(set) var accounts: [Account] = []

    /// The account currently selected by the user.
    public private(set) var activeAccount: Account?

    // MARK: - Private

    private let storageKey = "bzgram.accounts"
    private let activeKey  = "bzgram.activeAccountID"
    private let store: UserDefaults

    // MARK: - Init

    public init(store: UserDefaults = .standard) {
        self.store = store
        load()
    }

    // MARK: - Public API

    /// Add a new account.  Returns the newly created `Account`.
    /// There is no limit on how many accounts can be added.
    @discardableResult
    public func addAccount(displayName: String, phoneNumber: String) -> Account {
        let account = Account(displayName: displayName, phoneNumber: phoneNumber)
        accounts.append(account)
        save()
        if activeAccount == nil {
            setActive(account)
        }
        return account
    }

    /// Mark the account with `id` as authenticated (login completed).
    public func markAuthenticated(_ id: UUID, telegramUserID: Int64? = nil, displayName: String? = nil) {
        update(id: id) { account in
            account.isAuthenticated = true
            if let uid = telegramUserID { account.telegramUserID = uid }
            if let name = displayName   { account.displayName = name }
        }
    }

    /// Mark the account with `id` as logged out.
    public func logout(_ id: UUID) {
        update(id: id) { account in
            account.isAuthenticated = false
            account.telegramUserID = nil
        }
        // If the active account was logged out, fall back to the first authenticated one.
        if activeAccount?.id == id {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
            persistActiveID(activeAccount?.id)
        }
    }

    /// Remove an account entirely.
    public func removeAccount(_ id: UUID) {
        accounts.removeAll { $0.id == id }
        save()
        if activeAccount?.id == id {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
            persistActiveID(activeAccount?.id)
        }
    }

    /// Switch the active account.
    public func setActive(_ account: Account) {
        guard accounts.contains(where: { $0.id == account.id }) else { return }
        activeAccount = account
        persistActiveID(account.id)
    }

    // MARK: - Private helpers

    private func update(id: UUID, mutation: (inout Account) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        mutation(&accounts[index])
        save()
        if activeAccount?.id == id {
            activeAccount = accounts[index]
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        store.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = store.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Account].self, from: data)
        else { return }
        accounts = decoded
        if let rawID = store.string(forKey: activeKey),
           let uuid  = UUID(uuidString: rawID) {
            activeAccount = accounts.first(where: { $0.id == uuid })
        } else {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
        }
    }

    private func persistActiveID(_ id: UUID?) {
        store.set(id?.uuidString, forKey: activeKey)
    }
}

#if canImport(Combine)
// Retroactively add ObservableObject so SwiftUI views can observe account changes.
extension AccountManager: ObservableObject {}
#endif
