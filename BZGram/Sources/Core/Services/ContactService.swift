import Foundation
#if canImport(Combine)
import Combine
#endif

/// 联系人管理服务
/// 通过 TelegramClient 从 TDLib 获取真实联系人数据
public final class ContactService: ObservableObject {

    private let client: TelegramClient
    private var contacts: [Contact] = []
    private var contactsByID: [Int64: Contact] = [:]

    /// 必须从外部注入 TelegramClient，保持 DI 一致性
    public init(client: TelegramClient) {
        self.client = client
    }

    // MARK: - Public API

    /// 从 TDLib 获取联系人列表（按名称排序）
    public func fetchContacts() async -> [Contact] {
        do {
            let fetched = try await client.fetchContacts()
            updateContacts(fetched)
            return contacts.sorted { $0.displayName < $1.displayName }
        } catch {
            // TDLib 获取失败时返回本地缓存
            return contacts.sorted { $0.displayName < $1.displayName }
        }
    }

    /// 搜索联系人
    public func searchContacts(query: String) async -> [Contact] {
        guard !query.isEmpty else { return await fetchContacts() }
        return contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            ($0.username?.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.phoneNumber?.contains(query) ?? false)
        }
    }

    /// 通过 ID 获取联系人
    public func contact(for userID: Int64) -> Contact? {
        contactsByID[userID]
    }

    /// 更新联系人列表（来自 TDLib 推送或手动刷新）
    public func updateContacts(_ newContacts: [Contact]) {
        contacts = newContacts
        contactsByID = Dictionary(uniqueKeysWithValues: newContacts.map { ($0.id, $0) })
    }

    /// 添加联系人
    public func addContact(_ contact: Contact) {
        contacts.append(contact)
        contactsByID[contact.id] = contact
    }

    /// 删除联系人
    public func removeContact(id: Int64) {
        contacts.removeAll { $0.id == id }
        contactsByID.removeValue(forKey: id)
    }
}
