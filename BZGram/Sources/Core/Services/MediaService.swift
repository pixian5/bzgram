import Foundation

/// 媒体文件下载/上传/预览服务
/// 通过 TelegramClient 调用 TDLib downloadFile 执行实际下载
public final class MediaService {

    public static let shared = MediaService()

    /// 媒体文件缓存目录
    private let cacheDirectory: URL
    /// 当前下载任务（按 remoteFileId 去重）
    private var activeDownloads: [String: Task<URL, Error>] = [:]
    /// 可选的 TelegramClient（用于 TDLib 文件下载）
    private var client: TelegramClient?

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = base.appendingPathComponent("BZGram/media", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// 注入 TelegramClient（在 App 启动时调用）
    public func configure(client: TelegramClient) {
        self.client = client
    }

    // MARK: - 下载

    /// 下载媒体文件到本地缓存
    /// - Parameter attachment: 消息附件信息
    /// - Returns: 本地文件 URL
    public func downloadMedia(attachment: MessageAttachment) async throws -> URL {
        // 如果已有本地文件，直接返回
        if let localPath = attachment.localPath {
            let url = URL(fileURLWithPath: localPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        guard let remoteId = attachment.remoteFileId else {
            throw MediaError.noRemoteFile
        }

        // 防止重复下载（同一文件只发起一次请求）
        if let existing = activeDownloads[remoteId] {
            return try await existing.value
        }

        let capturedClient = client
        let capturedCacheDir = cacheDirectory

        let task = Task<URL, Error> {
            // 通过 TDLib 下载文件
            guard let client = capturedClient else {
                throw MediaError.downloadFailed
            }

            let localPath = try await client.downloadFile(remoteFileId: remoteId)
            guard !localPath.isEmpty else {
                throw MediaError.downloadFailed
            }

            // 如果 TDLib 返回的路径已经是本地文件，直接返回
            let sourceURL = URL(fileURLWithPath: localPath)
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                return sourceURL
            }

            // 否则将文件复制到缓存目录
            let fileName = attachment.fileName ?? remoteId
            let destURL = capturedCacheDir.appendingPathComponent(fileName)
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL
        }

        activeDownloads[remoteId] = task
        defer { activeDownloads.removeValue(forKey: remoteId) }

        return try await task.value
    }

    /// 获取缩略图
    public func thumbnail(for attachment: MessageAttachment) async -> URL? {
        if let thumbPath = attachment.thumbnailPath {
            let url = URL(fileURLWithPath: thumbPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    // MARK: - 缓存管理

    /// 计算缓存大小（字节）
    public func cacheSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: cacheDirectory,
                                                               includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    /// 格式化的缓存大小字符串
    public var formattedCacheSize: String {
        let size = cacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 清除所有媒体缓存
    public func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

public enum MediaError: LocalizedError {
    case noRemoteFile
    case downloadFailed
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .noRemoteFile: return "没有可用的远程文件。"
        case .downloadFailed: return "文件下载失败。"
        case .unsupportedFormat: return "不支持的文件格式。"
        }
    }
}
