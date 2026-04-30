import Foundation

/// Telegram 联系人
public struct Contact: Identifiable, Codable, Equatable, Hashable {
    /// Telegram 用户 ID
    public let id: Int64
    /// 显示名称
    public var displayName: String
    /// 用户名（@xxx）
    public var username: String?
    /// 手机号
    public var phoneNumber: String?
    /// 头像 URL
    public var avatarURL: URL?
    /// 最后在线时间
    public var lastSeen: Date?
    /// 在线状态
    public var status: OnlineStatus
    /// 是否为互相联系人
    public var isMutualContact: Bool

    public enum OnlineStatus: String, Codable {
        case online
        case offline
        case recently
        case lastWeek
        case lastMonth
        case unknown
    }

    public init(
        id: Int64,
        displayName: String,
        username: String? = nil,
        phoneNumber: String? = nil,
        avatarURL: URL? = nil,
        lastSeen: Date? = nil,
        status: OnlineStatus = .unknown,
        isMutualContact: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
        self.lastSeen = lastSeen
        self.status = status
        self.isMutualContact = isMutualContact
    }

    /// 显示名称的首字母（用于头像占位符）
    public var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    /// 状态描述文字
    public var statusText: String {
        switch status {
        case .online: return "在线"
        case .offline:
            if let lastSeen = lastSeen {
                let formatter = RelativeDateTimeFormatter()
                formatter.locale = Locale(identifier: "zh_CN")
                return "最后上线 " + formatter.localizedString(for: lastSeen, relativeTo: Date())
            }
            return "离线"
        case .recently: return "最近上线"
        case .lastWeek: return "一周内上线"
        case .lastMonth: return "一个月内上线"
        case .unknown: return "未知"
        }
    }
}
