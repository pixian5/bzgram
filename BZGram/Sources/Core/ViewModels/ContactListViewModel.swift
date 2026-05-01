import Foundation
#if canImport(Combine)
import Combine

/// 联系人列表 ViewModel
/// 通过外部注入 ContactService 保持 DI 一致性
@MainActor
public final class ContactListViewModel: ObservableObject {

    @Published public var contacts: [Contact] = []
    @Published public var isLoading: Bool = false
    @Published public var searchQuery: String = ""

    private let contactService: ContactService

    /// 必须从外部注入 ContactService（不再使用默认参数）
    public init(contactService: ContactService) {
        self.contactService = contactService
    }

    /// 加载联系人
    public func loadContacts() async {
        isLoading = true
        contacts = await contactService.fetchContacts()
        isLoading = false
    }

    /// 搜索过滤后的联系人列表
    public var filteredContacts: [Contact] {
        guard !searchQuery.isEmpty else { return contacts }
        return contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.username?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    /// 按首字母分组的联系人
    public var groupedContacts: [(String, [Contact])] {
        let filtered = filteredContacts
        let grouped = Dictionary(grouping: filtered) { contact -> String in
            let firstChar = contact.displayName.first.map(String.init) ?? "#"
            return firstChar.uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    /// 在线联系人数量
    public var onlineCount: Int {
        contacts.filter { $0.status == .online }.count
    }
}
#else
@MainActor
public final class ContactListViewModel {
    public var contacts: [Contact] = []
    public var isLoading: Bool = false
    public var searchQuery: String = ""
    private let contactService: ContactService

    public init(contactService: ContactService) {
        self.contactService = contactService
    }

    public func loadContacts() async {
        isLoading = true
        contacts = await contactService.fetchContacts()
        isLoading = false
    }
}
#endif
