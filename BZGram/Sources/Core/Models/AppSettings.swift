import Foundation

/// 外观模式
public enum AppearanceMode: String, Codable, CaseIterable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
}

/// 应用全局设置
public struct AppSettings: Codable, Equatable {
    /// 全局翻译配置（应用于所有未单独覆盖的会话）
    public var globalTranslation: TranslationSettings
    /// 当前使用的账号 UUID
    public var activeAccountID: UUID?
    /// 外观模式
    public var appearanceMode: AppearanceMode
    /// 是否启用消息预览通知
    public var notificationPreview: Bool
    /// 是否启用发送消息声音
    public var sendMessageSound: Bool
    /// 字体大小缩放倍率（1.0 = 正常）
    public var fontScale: Double
    /// 幽灵模式（不发已读回执、不发正在输入状态）
    public var ghostMode: Bool
    /// 防撤回模式（本地保留被撤回的消息）
    public var antiDelete: Bool
    /// 聊天摘要的目标语言；为 `nil` 时跟随系统语言
    public var summaryLanguageCode: String?
    /// 本地独立密码锁（生物识别）
    public var appLock: Bool

    public init(
        globalTranslation: TranslationSettings = .disabled,
        activeAccountID: UUID? = nil,
        appearanceMode: AppearanceMode = .system,
        notificationPreview: Bool = true,
        sendMessageSound: Bool = true,
        fontScale: Double = 1.0,
        ghostMode: Bool = false,
        antiDelete: Bool = false,
        summaryLanguageCode: String? = nil,
        appLock: Bool = false
    ) {
        self.globalTranslation = globalTranslation
        self.activeAccountID = activeAccountID
        self.appearanceMode = appearanceMode
        self.notificationPreview = notificationPreview
        self.sendMessageSound = sendMessageSound
        self.fontScale = fontScale
        self.ghostMode = ghostMode
        self.antiDelete = antiDelete
        self.summaryLanguageCode = summaryLanguageCode
        self.appLock = appLock
    }
}
