import Foundation

/// 媒体文件下载/上传/预览服务
public final class MediaService {

    public static let shared = MediaService()

    /// 媒体文件缓存目录
    private let cacheDirectory: URL
    /// 当前下载任务
    private var activeDownloads: [String: Task<URL, Error>] = [:]

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = base.appendingPathComponent("BZGram/media", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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

        // 防止重复下载
        if let existing = activeDownloads[remoteId] {
            return try await existing.value
        }

        let task = Task<URL, Error> {
            // TODO: 通过 TDLib 的 downloadFile API 执行实际下载
            // 目前返回占位路径
            let fileName = attachment.fileName ?? remoteId
            let localURL = cacheDirectory.appendingPathComponent(fileName)
            return localURL
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
