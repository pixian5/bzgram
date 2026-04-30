import Foundation
#if canImport(Combine)
import Combine

/// 账号管理界面的 ViewModel
@MainActor
public final class AccountListViewModel: ObservableObject {

    @Published public var accounts: [Account] = []
    @Published public var activeAccount: Account?
    @Published public var showAddAccount: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let manager: AccountManager

    public init(manager: AccountManager) {
        self.manager = manager
        self.accounts = manager.accounts
        self.activeAccount = manager.activeAccount
    }

    /// 添加新账号
    public func addAccount(displayName: String, phoneNumber: String) {
        guard !displayName.isEmpty, !phoneNumber.isEmpty else {
            errorMessage = "请填写完整的账号信息"
            return
        }
        manager.addAccount(displayName: displayName, phoneNumber: phoneNumber)
        refresh()
        showAddAccount = false
    }

    /// 切换活跃账号
    public func selectAccount(_ account: Account) {
        manager.setActive(account)
        refresh()
    }

    /// 注销账号
    public func logoutAccount(_ account: Account) {
        manager.logout(account.id)
        refresh()
    }

    /// 移除账号
    public func removeAccount(_ account: Account) {
        manager.removeAccount(account.id)
        refresh()
    }

    /// 移动账号排序
    public func moveAccount(from source: IndexSet, to destination: Int) {
        manager.moveAccount(from: source, to: destination)
        refresh()
    }

    /// 刷新数据
    public func refresh() {
        accounts = manager.accounts
        activeAccount = manager.activeAccount
        errorMessage = nil
    }

    /// 已认证的账号数量
    public var authenticatedCount: Int {
        accounts.filter(\.isAuthenticated).count
    }

    /// 总账号数量
    public var totalCount: Int {
        accounts.count
    }
}
#else
@MainActor
public final class AccountListViewModel {

    public var accounts: [Account] = []
    public var activeAccount: Account?
    public var showAddAccount: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String?

    private let manager: AccountManager

    public init(manager: AccountManager) {
        self.manager = manager
        self.accounts = manager.accounts
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

    public func moveAccount(from source: IndexSet, to destination: Int) {
        manager.moveAccount(from: source, to: destination)
        refresh()
    }

    public func refresh() {
        accounts = manager.accounts
        activeAccount = manager.activeAccount
    }

    public var authenticatedCount: Int {
        accounts.filter(\.isAuthenticated).count
    }

    public var totalCount: Int {
        accounts.count
    }
}
#endif
