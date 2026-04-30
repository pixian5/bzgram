import Foundation
#if canImport(Combine)
import Combine
#endif

/// 联系人管理服务
public final class ContactService {

    private var contacts: [Contact] = []
    private var contactsByID: [Int64: Contact] = [:]

    public init() {}

    // MARK: - Public API

    /// 获取所有联系人（按名称排序）
    public func fetchContacts() async -> [Contact] {
        return contacts.sorted { $0.displayName < $1.displayName }
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

    /// 更新联系人列表
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
