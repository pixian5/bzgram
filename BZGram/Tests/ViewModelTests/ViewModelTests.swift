import XCTest
@testable import BZGramCore

@MainActor
final class ViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainService.shared.deleteAll()
    }

    override func tearDown() {
        KeychainService.shared.deleteAll()
        super.tearDown()
    }

    // MARK: - AccountListViewModel

    func testAccountListVM_addAccount() {
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let vm = AccountListViewModel(manager: manager)

        vm.addAccount(displayName: "Alice", phoneNumber: "+123")
        XCTAssertEqual(vm.accounts.count, 1)
        XCTAssertEqual(vm.activeAccount?.displayName, "Alice")
    }

    func testAccountListVM_selectAccount() {
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let vm = AccountListViewModel(manager: manager)

        vm.addAccount(displayName: "Alice", phoneNumber: "+1")
        vm.addAccount(displayName: "Bob", phoneNumber: "+2")
        let bob = vm.accounts[1]
        vm.selectAccount(bob)
        XCTAssertEqual(vm.activeAccount?.displayName, "Bob")
    }

    func testAccountListVM_removeAccount() {
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let vm = AccountListViewModel(manager: manager)

        vm.addAccount(displayName: "Alice", phoneNumber: "+1")
        XCTAssertEqual(vm.accounts.count, 1)
        let alice = vm.accounts[0]
        vm.removeAccount(alice)
        XCTAssertEqual(vm.accounts.count, 0)
    }

    func testAccountListVM_authenticatedCount() {
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let vm = AccountListViewModel(manager: manager)

        let a = manager.addAccount(displayName: "Alice", phoneNumber: "+1")
        manager.markAuthenticated(a.id)
        manager.addAccount(displayName: "Bob", phoneNumber: "+2")
        vm.refresh()

        XCTAssertEqual(vm.authenticatedCount, 1)
        XCTAssertEqual(vm.totalCount, 2)
    }

    func testAccountListVM_emptyAddFails() {
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let vm = AccountListViewModel(manager: manager)

        vm.addAccount(displayName: "", phoneNumber: "")
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.accounts.isEmpty)
    }

    // MARK: - ChatListViewModel

    func testChatListVM_filter() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let vm = ChatListViewModel(settingsStore: store, sessionStore: session)

        vm.chats = [
            Chat(id: 1, title: "Private", type: .private, unreadCount: 3),
            Chat(id: 2, title: "Group", type: .group, unreadCount: 0),
            Chat(id: 3, title: "Channel", type: .channel, unreadCount: 1)
        ]

        vm.selectedFilter = .unread
        XCTAssertEqual(vm.filteredChats.count, 2) // Private + Channel

        vm.selectedFilter = .groups
        XCTAssertEqual(vm.filteredChats.count, 1)
        XCTAssertEqual(vm.filteredChats.first?.title, "Group")

        vm.selectedFilter = .channels
        XCTAssertEqual(vm.filteredChats.count, 1)
        XCTAssertEqual(vm.filteredChats.first?.title, "Channel")

        vm.selectedFilter = .all
        XCTAssertEqual(vm.filteredChats.count, 3)
    }

    func testChatListVM_search() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let vm = ChatListViewModel(settingsStore: store, sessionStore: session)

        vm.chats = [
            Chat(id: 1, title: "Alice"),
            Chat(id: 2, title: "Bob"),
            Chat(id: 3, title: "Charlie")
        ]

        vm.searchQuery = "ali"
        XCTAssertEqual(vm.filteredChats.count, 1)
        XCTAssertEqual(vm.filteredChats.first?.title, "Alice")
    }

    func testChatListVM_totalUnread() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let vm = ChatListViewModel(settingsStore: store, sessionStore: session)

        vm.chats = [
            Chat(id: 1, title: "A", unreadCount: 3),
            Chat(id: 2, title: "B", unreadCount: 5)
        ]

        XCTAssertEqual(vm.totalUnreadCount, 8)
    }

    func testChatListVM_translationOverride() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(
            keychain: .shared,
            legacyStore: UserDefaults(suiteName: "test.\(UUID())")!
        )
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let vm = ChatListViewModel(settingsStore: store, sessionStore: session)

        vm.chats = [Chat(id: 1, title: "Test")]
        let chat = vm.chats[0]

        let override = TranslationSettings.autoTranslate(to: "de")
        vm.setTranslationOverride(override, for: chat)
        XCTAssertEqual(vm.chats[0].translationOverride?.targetLanguageCode, "de")

        vm.clearTranslationOverride(for: vm.chats[0])
        XCTAssertNil(vm.chats[0].translationOverride)
    }

    // MARK: - ContactListViewModel（DI 统一，必须注入 ContactService）

    func testContactListVM_groupedContacts() {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        service.addContact(Contact(id: 1, displayName: "Alice"))
        service.addContact(Contact(id: 2, displayName: "Bob"))
        service.addContact(Contact(id: 3, displayName: "Adam"))
        let vm = ContactListViewModel(contactService: service)
        vm.contacts = [
            Contact(id: 1, displayName: "Alice"),
            Contact(id: 2, displayName: "Bob"),
            Contact(id: 3, displayName: "Adam")
        ]

        let groups = vm.groupedContacts
        XCTAssertEqual(groups.count, 2) // A, B
        XCTAssertEqual(groups.first?.0, "A")
        XCTAssertEqual(groups.first?.1.count, 2)
    }

    func testContactListVM_search() {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        let vm = ContactListViewModel(contactService: service)
        vm.contacts = [
            Contact(id: 1, displayName: "Alice"),
            Contact(id: 2, displayName: "Bob")
        ]

        vm.searchQuery = "Bo"
        XCTAssertEqual(vm.filteredContacts.count, 1)
        XCTAssertEqual(vm.filteredContacts.first?.displayName, "Bob")
    }

    func testContactListVM_onlineCount() {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        let vm = ContactListViewModel(contactService: service)
        vm.contacts = [
            Contact(id: 1, displayName: "Alice", status: .online),
            Contact(id: 2, displayName: "Bob", status: .offline),
            Contact(id: 3, displayName: "Charlie", status: .online)
        ]
        XCTAssertEqual(vm.onlineCount, 2)
    }

    // MARK: - ChatViewModel（消息状态）

    func testChatVM_hasFailedMessages() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(keychain: .shared, legacyStore: UserDefaults(suiteName: "test.\(UUID())")!)
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let chat = Chat(id: 1, title: "Test")
        let vm = ChatViewModel(chat: chat, settingsStore: store, sessionStore: session)

        vm.messages = [
            Message(id: 1, chatID: 1, senderName: "A", originalText: "OK", sendStatus: .sent),
            Message(id: 2, chatID: 1, senderName: "A", originalText: "Fail", sendStatus: .failed)
        ]

        XCTAssertTrue(vm.hasFailedMessages)
    }

    func testChatVM_noFailedMessages() {
        let store = SettingsStore(store: UserDefaults(suiteName: "test.\(UUID())")!)
        let manager = AccountManager(keychain: .shared, legacyStore: UserDefaults(suiteName: "test.\(UUID())")!)
        let session = TelegramSessionStore(client: MockTelegramClient(), accountManager: manager)
        let chat = Chat(id: 1, title: "Test")
        let vm = ChatViewModel(chat: chat, settingsStore: store, sessionStore: session)

        vm.messages = [
            Message(id: 1, chatID: 1, senderName: "A", originalText: "OK", sendStatus: .sent)
        ]

        XCTAssertFalse(vm.hasFailedMessages)
    }
}
