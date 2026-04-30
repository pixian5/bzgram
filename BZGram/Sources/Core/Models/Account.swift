import Foundation

/// BZGram 管理的 Telegram 账号。
/// 支持无限数量的账号，每个账号拥有独立的 TDLib 实例。
public struct Account: Identifiable, Codable, Equatable, Hashable {

    /// 本地唯一标识（非 Telegram 用户 ID，登录后才可获得后者）
    public let id: UUID

    /// Telegram 数字用户 ID，认证成功后填充
    public var telegramUserID: Int64?

    /// 账号在切换器中显示的名称
    public var displayName: String

    /// 登录用的手机号
    public var phoneNumber: String

    /// 头像 URL（远程或缓存本地路径）
    public var avatarURL: URL?

    /// 是否已认证/连接
    public var isAuthenticated: Bool

    /// 该账号的 TDLib 实例标识，用于数据目录隔离
    public let tdlibInstanceId: String

    /// 账号添加到 BZGram 的时间
    public let addedAt: Date

    /// 最近一次活跃时间（上次切换到此账号的时间）
    public var lastActiveAt: Date?

    /// 账号排序权重（用于自定义排序）
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        telegramUserID: Int64? = nil,
        displayName: String,
        phoneNumber: String,
        avatarURL: URL? = nil,
        isAuthenticated: Bool = false,
        tdlibInstanceId: String? = nil,
        addedAt: Date = Date(),
        lastActiveAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.telegramUserID = telegramUserID
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
        self.isAuthenticated = isAuthenticated
        self.tdlibInstanceId = tdlibInstanceId ?? id.uuidString
        self.addedAt = addedAt
        self.lastActiveAt = lastActiveAt
        self.sortOrder = sortOrder
    }

    /// 显示名称的首字母（用于头像占位符）
    public var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
