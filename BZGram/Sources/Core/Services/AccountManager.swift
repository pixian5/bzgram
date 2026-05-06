import Foundation
#if canImport(Combine)
import Combine
#endif

/// 管理所有 Telegram 账号的核心服务。
///
/// - 无上限账号支持
/// - Keychain 安全持久化
/// - 多 TDLib 实例的创建/销毁/隔离
/// - 账号切换/添加/删除
public final class AccountManager {

    // MARK: - State

    /// App 中所有已知账号，按添加顺序排列
    public private(set) var accounts: [Account] = []

    /// 当前用户选中的活跃账号
    public private(set) var activeAccount: Account?

    /// Every account's TelegramClient, keyed by account UUID.
    public private(set) var clientInstances: [UUID: TelegramClient] = [:]

    // MARK: - Guest session

    /// Cached TelegramClient for the initial "no accounts yet" login flow.
    /// Using a single cached instance prevents multiple TDLib processes from
    /// contending over the same database directory.
    private var guestClient: TelegramClient?

    /// True while a guest-session client is active (i.e. first-time login is in progress).
    public var hasGuestSession: Bool { guestClient != nil }

    // MARK: - Private

    private let keychainAccountsKey = "bzgram.accounts"
    private let keychainActiveKey = "bzgram.activeAccountID"
    private let keychain: KeychainService
    /// 兼容旧版 UserDefaults 迁移的 fallback
    private let legacyStore: UserDefaults

    // MARK: - Init

    public init(
        keychain: KeychainService = .shared,
        legacyStore: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.legacyStore = legacyStore

        // Load accounts first so we can check whether guest_session is in use.
        load()

        // Only clean up the guest_session directory when no account depends on it.
        // (If an account was created via the guest login flow its tdlibInstanceId is
        // "guest_session" and we must keep the database intact across restarts.)
        if !accounts.contains(where: { $0.tdlibInstanceId == "guest_session" }) {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let guestPath = appSupport.appendingPathComponent("BZGram/accounts/guest_session")
            try? FileManager.default.removeItem(at: guestPath)
        }
    }

    // MARK: - 账号管理 Public API

    /// 添加新账号，没有数量上限。返回新创建的 `Account`。
    @discardableResult
    public func addAccount(displayName: String, phoneNumber: String, tdlibInstanceId: String? = nil) -> Account {
        let account = Account(
            displayName: displayName,
            phoneNumber: phoneNumber,
            tdlibInstanceId: tdlibInstanceId,
            sortOrder: accounts.count
        )
        accounts.append(account)
        save()
        if activeAccount == nil {
            setActive(account)
        }
        return account
    }

    /// 标记账号已认证（登录完成）
    public func markAuthenticated(_ id: UUID, telegramUserID: Int64? = nil, displayName: String? = nil) {
        update(id: id) { account in
            account.isAuthenticated = true
            if let uid = telegramUserID { account.telegramUserID = uid }
            if let name = displayName { account.displayName = name }
        }
    }

    /// 注销某账号
    public func logout(_ id: UUID) {
        update(id: id) { account in
            account.isAuthenticated = false
            account.telegramUserID = nil
        }
        // 销毁该账号的 TDLib 实例
        clientInstances.removeValue(forKey: id)
        // 如果注销的是活跃账号，回退到首个已认证账号
        if activeAccount?.id == id {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
            persistActiveID(activeAccount?.id)
        }
    }

    /// 彻底移除账号
    public func removeAccount(_ id: UUID) {
        // 销毁 TDLib 实例
        clientInstances.removeValue(forKey: id)
        accounts.removeAll { $0.id == id }
        save()
        if activeAccount?.id == id {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
            persistActiveID(activeAccount?.id)
        }
    }

    /// 切换活跃账号
    public func setActive(_ account: Account) {
        guard accounts.contains(where: { $0.id == account.id }) else { return }
        // 更新上次活跃时间
        update(id: account.id) { $0.lastActiveAt = Date() }
        activeAccount = accounts.first(where: { $0.id == account.id })
        persistActiveID(account.id)
    }

    /// 移动账号排序顺序
    public func moveAccount(from source: IndexSet, to destination: Int) {
        // 手动实现 move 操作（避免依赖 SwiftUI 的 Array 扩展）
        var items = accounts
        let movedItems = source.map { items[$0] }
        // 按从大到小的索引删除，避免索引偏移
        for index in source.sorted().reversed() {
            items.remove(at: index)
        }
        let insertIndex = min(destination, items.count)
        items.insert(contentsOf: movedItems, at: insertIndex)
        accounts = items
        for (index, _) in accounts.enumerated() {
            accounts[index].sortOrder = index
        }
        save()
    }

    // MARK: - TDLib 实例管理

    /// 获取或创建某账号的 TelegramClient 实例
    /// 每个账号拥有独立的 TDLib 数据目录，实现完全隔离
    public func clientForAccount(_ accountID: UUID) -> TelegramClient {
        if let existing = clientInstances[accountID] {
            return existing
        }
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return EmptyTelegramClient()
        }
        let client = createClient(for: account)
        clientInstances[accountID] = client
        return client
    }

    /// 获取当前活跃账号的 TelegramClient
    public var activeClient: TelegramClient {
        // 1. 如果有活跃账号，直接返回其对应的 Client
        if let active = activeAccount {
            return clientForAccount(active.id)
        }

        // 2. 如果没有活跃账号但账号列表不为空，尝试使用第一个账号（防止初始化时的逻辑真空）
        if let firstAccount = accounts.first {
            return clientForAccount(firstAccount.id)
        }

        // 3. 完全没有账号时使用 guest_session 客户端（首次登录流程）。
        //    缓存同一个实例，确保 submitPhoneNumber / submitCode 等步骤
        //    共享同一个 TDLib 进程，避免多进程争抢同一数据库文件而返回 error 1。
        if guestClient == nil {
            guestClient = TelegramClientFactory.makeDefaultClient(instanceId: "guest_session")
        }
        return guestClient!
    }

    /// 登录完成后，将 guest-session 客户端迁移到正式账号。
    /// 确保已认证的 TDLib 状态（含会话数据库）持续供该账号使用。
    public func transferGuestSession(to accountID: UUID) {
        guard let guest = guestClient else { return }
        clientInstances[accountID] = guest
        guestClient = nil
    }

    /// 销毁所有 TDLib 实例
    public func destroyAllClients() {
        clientInstances.removeAll()
    }

    // MARK: - Private helpers

    private func createClient(for account: Account) -> TelegramClient {
        return TelegramClientFactory.makeDefaultClient(instanceId: account.tdlibInstanceId)
    }

    private func update(id: UUID, mutation: (inout Account) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        mutation(&accounts[index])
        save()
        if activeAccount?.id == id {
            activeAccount = accounts[index]
        }
    }

    private func save() {
        _ = keychain.saveCodable(accounts, forKey: keychainAccountsKey)
    }

    private func load() {
        // 优先从 Keychain 加载
        if let keychainAccounts = keychain.loadCodable([Account].self, forKey: keychainAccountsKey) {
            accounts = keychainAccounts
        } else {
            // 回退到旧版 UserDefaults（一次性迁移）
            migrateFromUserDefaults()
        }

        // 恢复活跃账号
        if let activeIDData = keychain.load(forKey: keychainActiveKey),
           let rawID = String(data: activeIDData, encoding: .utf8),
           let uuid = UUID(uuidString: rawID) {
            activeAccount = accounts.first(where: { $0.id == uuid })
        } else {
            activeAccount = accounts.first(where: { $0.isAuthenticated })
        }
    }

    /// 从旧版 UserDefaults 迁移到 Keychain（只执行一次）
    private func migrateFromUserDefaults() {
        let legacyKey = "bzgram.accounts"
        guard let data = legacyStore.data(forKey: legacyKey),
              let decoded = try? JSONDecoder().decode([Account].self, from: data)
        else { return }

        accounts = decoded
        // 保存到 Keychain
        save()
        // 清理 UserDefaults 中的旧数据
        legacyStore.removeObject(forKey: legacyKey)
        legacyStore.removeObject(forKey: "bzgram.activeAccountID")
    }

    private func persistActiveID(_ id: UUID?) {
        if let id = id, let data = id.uuidString.data(using: .utf8) {
            _ = keychain.save(data, forKey: keychainActiveKey)
        } else {
            _ = keychain.delete(forKey: keychainActiveKey)
        }
    }
}

#if canImport(Combine)
extension AccountManager: ObservableObject {}
#endif
