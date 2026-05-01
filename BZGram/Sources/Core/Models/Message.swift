import Foundation

/// 消息内容类型
public enum MessageContentType: String, Codable, Equatable {
    case text
    case photo
    case video
    case document
    case sticker
    case voice
    case animation
    case location
    case contact
    case unsupported
}

/// 消息发送状态
public enum MessageSendStatus: String, Codable, Equatable {
    /// 正在发送（UI 显示加载指示器）
    case sending
    /// 已发送到服务器
    case sent
    /// 发送失败（UI 显示红色感叹号 + 重试按钮）
    case failed
}

/// 附件信息
public struct MessageAttachment: Codable, Equatable {
    /// 文件名
    public let fileName: String?
    /// MIME 类型
    public let mimeType: String?
    /// 文件大小（字节）
    public let fileSize: Int64?
    /// 本地文件路径（下载后填充）
    public var localPath: String?
    /// 远程文件 ID
    public let remoteFileId: String?
    /// 缩略图本地路径
    public var thumbnailPath: String?
    /// 图片/视频宽度
    public let width: Int?
    /// 图片/视频高度
    public let height: Int?
    /// 视频/语音时长（秒）
    public let duration: Int?

    public init(
        fileName: String? = nil,
        mimeType: String? = nil,
        fileSize: Int64? = nil,
        localPath: String? = nil,
        remoteFileId: String? = nil,
        thumbnailPath: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        duration: Int? = nil
    ) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.localPath = localPath
        self.remoteFileId = remoteFileId
        self.thumbnailPath = thumbnailPath
        self.width = width
        self.height = height
        self.duration = duration
    }
}

/// 会话中的一条消息。
public struct Message: Identifiable, Codable, Equatable {

    public let id: Int64
    public let chatID: Int64
    public let senderName: String
    /// 发送者用户 ID（如果是用户发送的）
    public let senderUserID: Int64?
    public let originalText: String
    /// 翻译后的文本，当自动翻译开启时由 `TranslationService` 填充
    public var translatedText: String?
    public let date: Date
    public let isOutgoing: Bool
    /// 消息内容类型
    public let contentType: MessageContentType
    /// 附件信息（图片、视频、文档等）
    public var attachment: MessageAttachment?
    /// 消息是否已被编辑
    public var isEdited: Bool
    /// 回复的消息 ID（如果是回复消息）
    public let replyToMessageId: Int64?
    /// 消息是否可撤回
    public var canBeDeleted: Bool
    /// 消息是否可编辑
    public var canBeEdited: Bool
    /// 发送状态（仅对外发消息有意义）
    public var sendStatus: MessageSendStatus

    public init(
        id: Int64,
        chatID: Int64,
        senderName: String,
        senderUserID: Int64? = nil,
        originalText: String,
        translatedText: String? = nil,
        date: Date = Date(),
        isOutgoing: Bool = false,
        contentType: MessageContentType = .text,
        attachment: MessageAttachment? = nil,
        isEdited: Bool = false,
        replyToMessageId: Int64? = nil,
        canBeDeleted: Bool = true,
        canBeEdited: Bool = false,
        sendStatus: MessageSendStatus = .sent
    ) {
        self.id = id
        self.chatID = chatID
        self.senderName = senderName
        self.senderUserID = senderUserID
        self.originalText = originalText
        self.translatedText = translatedText
        self.date = date
        self.isOutgoing = isOutgoing
        self.contentType = contentType
        self.attachment = attachment
        self.isEdited = isEdited
        self.replyToMessageId = replyToMessageId
        self.canBeDeleted = canBeDeleted
        self.canBeEdited = canBeEdited
        self.sendStatus = sendStatus
    }

    /// 根据翻译设置返回应显示的文本
    ///
    /// - 如果自动翻译开启且有翻译结果，返回翻译文本
    /// - 否则返回原文
    public func displayText(settings: TranslationSettings) -> String {
        guard settings.autoTranslateEnabled, let translated = translatedText else {
            return originalText
        }
        return translated
    }

    /// 格式化的消息时间（仅时:分）
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 是否为纯文本消息
    public var isTextOnly: Bool {
        contentType == .text && attachment == nil
    }
}
