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

    public init(
        globalTranslation: TranslationSettings = .disabled,
        activeAccountID: UUID? = nil,
        appearanceMode: AppearanceMode = .system,
        notificationPreview: Bool = true,
        sendMessageSound: Bool = true,
        fontScale: Double = 1.0
    ) {
        self.globalTranslation = globalTranslation
        self.activeAccountID = activeAccountID
        self.appearanceMode = appearanceMode
        self.notificationPreview = notificationPreview
        self.sendMessageSound = sendMessageSound
        self.fontScale = fontScale
    }
}
