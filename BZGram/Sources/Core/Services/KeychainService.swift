import Foundation
import Security

/// 安全的 Keychain 存储服务，用于持久化账号敏感数据。
/// 所有账号信息（手机号、认证状态等）存储在 Keychain 中而非 UserDefaults。
public final class KeychainService {

    /// 单例访问
    public static let shared = KeychainService()

    private let serviceName = "com.pixian5.bzgram.accounts"

    private init() {}

    // MARK: - Public API

    /// 保存编码后的数据到 Keychain
    /// - Parameters:
    ///   - data: 要存储的数据
    ///   - key: 存储键
    @discardableResult
    public func save(_ data: Data, forKey key: String) -> Bool {
        // 先尝试删除旧值
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 从 Keychain 读取数据
    /// - Parameter key: 存储键
    /// - Returns: 存储的数据，如果不存在则返回 nil
    public func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// 删除 Keychain 中的数据
    /// - Parameter key: 存储键
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// 清除所有 BZGram 的 Keychain 数据
    @discardableResult
    public func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Codable 便利方法

    /// 编码并保存 Codable 对象
    public func saveCodable<T: Encodable>(_ object: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(object) else { return false }
        return save(data, forKey: key)
    }

    /// 从 Keychain 加载并解码 Codable 对象
    public func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = load(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
