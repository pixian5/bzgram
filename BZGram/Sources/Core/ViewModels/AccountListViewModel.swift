import Foundation
#if canImport(Combine)
import Combine

/// View-model for the account management screen and account switcher.
public final class AccountListViewModel: ObservableObject {

    @Published public var accounts: [Account] = []
    @Published public var activeAccount: Account?

    private let manager: AccountManager
    private weak var multiAccountManager: MultiAccountSessionManager?

    public init(manager: AccountManager, multiAccountManager: MultiAccountSessionManager? = nil) {
        self.manager             = manager
        self.multiAccountManager = multiAccountManager
        self.accounts            = manager.accounts
        self.activeAccount       = manager.activeAccount
    }

    public func addAccount(displayName: String, phoneNumber: String) {
        if let multiManager = multiAccountManager {
            multiManager.addAccount(displayName: displayName, phoneNumber: phoneNumber)
        } else {
            manager.addAccount(displayName: displayName, phoneNumber: phoneNumber)
        }
        refresh()
    }

    public func selectAccount(_ account: Account) {
        if let multiManager = multiAccountManager {
            multiManager.switchToAccount(account)
        } else {
            manager.setActive(account)
        }
        refresh()
    }

    public func logoutAccount(_ account: Account) {
        if let multiManager = multiAccountManager {
            Task { await multiManager.logoutAccount(account) }
        } else {
            manager.logout(account.id)
        }
        refresh()
    }

    public func removeAccount(_ account: Account) {
        if let multiManager = multiAccountManager {
            Task { await multiManager.removeAccount(account) }
        } else {
            manager.removeAccount(account.id)
        }
        refresh()
    }

    private func refresh() {
        accounts      = manager.accounts
        activeAccount = manager.activeAccount
    }
}
#else
/// View-model for the account management screen and account switcher.
public final class AccountListViewModel {

    public var accounts: [Account] = []
    public var activeAccount: Account?

    private let manager: AccountManager

    public init(manager: AccountManager) {
        self.manager    = manager
        self.accounts   = manager.accounts
        self.activeAccount = manager.activeAccount
    }

    public func addAccount(displayName: String, phoneNumber: String) {
        manager.addAccount(displayName: displayName, phoneNumber: phoneNumber)
        refresh()
    }

    public func selectAccount(_ account: Account) {
        manager.setActive(account)
        refresh()
    }

    public func logoutAccount(_ account: Account) {
        manager.logout(account.id)
        refresh()
    }

    public func removeAccount(_ account: Account) {
        manager.removeAccount(account.id)
        refresh()
    }

    private func refresh() {
        accounts       = manager.accounts
        activeAccount  = manager.activeAccount
    }
}
#endif
