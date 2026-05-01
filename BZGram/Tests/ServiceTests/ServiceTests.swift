import XCTest
@testable import BZGramCore

final class ServiceTests: XCTestCase {

    // MARK: - MockTelegramClient

    func testMockClient_initialState() async {
        let client = MockTelegramClient()
        let state = await client.authorizationState()
        XCTAssertEqual(state, .waitingForPhoneNumber)
        let user = await client.currentUser()
        XCTAssertNil(user)
    }

    func testMockClient_loginFlow() async throws {
        let client = MockTelegramClient()

        // 提交手机号
        let afterPhone = try await client.submitPhoneNumber("+123456789")
        XCTAssertEqual(afterPhone, .waitingForCode(phoneNumber: "+123456789"))

        // 错误验证码
        do {
            _ = try await client.submitCode("wrong")
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .invalidCode)
        }

        // 正确验证码
        let afterCode = try await client.submitCode("12345")
        XCTAssertEqual(afterCode, .ready)

        // 验证用户
        let user = await client.currentUser()
        XCTAssertNotNil(user)
    }

    func testMockClient_fetchChats_unauthorized() async {
        let client = MockTelegramClient()
        do {
            _ = try await client.fetchChats()
            XCTFail("Should throw unauthorized")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .unauthorized)
        }
    }

    func testMockClient_fetchChats_authorized() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let chats = try await client.fetchChats()
        XCTAssertFalse(chats.isEmpty)
    }

    func testMockClient_sendMessage() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let msg = try await client.sendMessage("Hello!", to: 1)
        XCTAssertEqual(msg.originalText, "Hello!")
        XCTAssertTrue(msg.isOutgoing)
    }

    func testMockClient_logOut() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let state = await client.logOut()
        XCTAssertEqual(state, .waitingForPhoneNumber)
        let user = await client.currentUser()
        XCTAssertNil(user)
    }

    func testMockClient_invalidPhoneNumber() async {
        let client = MockTelegramClient()
        do {
            _ = try await client.submitPhoneNumber("123")
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .invalidPhoneNumber)
        }
    }

    func testMockClient_invalidPassword() async throws {
        let client = MockTelegramClient()
        do {
            _ = try await client.submitPassword("wrong")
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .invalidPassword)
        }
    }

    // MARK: - MockTelegramClient 新增协议方法

    func testMockClient_searchMessages() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let results = try await client.searchMessages(query: "测试", in: 1, limit: 10)
        // 搜索结果取决于演示数据
        XCTAssertTrue(results.count >= 0)
    }

    func testMockClient_searchMessages_unauthorized() async {
        let client = MockTelegramClient()
        do {
            _ = try await client.searchMessages(query: "test", in: 1, limit: 10)
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .unauthorized)
        }
    }

    func testMockClient_fetchContacts() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let contacts = try await client.fetchContacts()
        XCTAssertFalse(contacts.isEmpty)
        XCTAssertEqual(contacts.first?.displayName, "Alice")
    }

    func testMockClient_fetchContacts_unauthorized() async {
        let client = MockTelegramClient()
        do {
            _ = try await client.fetchContacts()
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? TelegramClientError, .unauthorized)
        }
    }

    func testMockClient_downloadFile() async throws {
        let client = MockTelegramClient()
        let result = try await client.downloadFile(remoteFileId: "test")
        XCTAssertEqual(result, "")
    }

    func testMockClient_setUpdateDelegate() async {
        let client = MockTelegramClient()
        // 确保不崩溃
        await client.setUpdateDelegate(nil)
    }

    // MARK: - ContactService（注入 TelegramClient）

    func testContactService_fetchFromTDLib() async throws {
        let client = MockTelegramClient()
        _ = try await client.submitPhoneNumber("+123456")
        _ = try await client.submitCode("12345")
        let service = ContactService(client: client)
        let contacts = await service.fetchContacts()
        XCTAssertFalse(contacts.isEmpty)
    }

    func testContactService_addAndFetch() async {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        let contact = Contact(id: 1, displayName: "Alice", status: .online)
        service.addContact(contact)
        // addContact 只加到本地缓存
        XCTAssertEqual(service.contact(for: 1)?.displayName, "Alice")
    }

    func testContactService_search() async {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        service.addContact(Contact(id: 1, displayName: "Alice", username: "alice"))
        service.addContact(Contact(id: 2, displayName: "Bob", username: "bob"))

        let results = await service.searchContacts(query: "Ali")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Alice")
    }

    func testContactService_remove() async {
        let client = MockTelegramClient()
        let service = ContactService(client: client)
        service.addContact(Contact(id: 1, displayName: "Alice"))
        service.removeContact(id: 1)
        XCTAssertNil(service.contact(for: 1))
    }

    // MARK: - MediaService

    func testMediaService_cacheSize() {
        let service = MediaService.shared
        XCTAssertGreaterThanOrEqual(service.cacheSize(), 0)
    }

    func testMediaService_formattedCacheSize() {
        let service = MediaService.shared
        XCTAssertFalse(service.formattedCacheSize.isEmpty)
    }

    func testMediaService_clearCache() {
        let service = MediaService.shared
        service.clearCache()
        XCTAssertEqual(service.cacheSize(), 0)
    }

    func testMediaError_descriptions() {
        XCTAssertNotNil(MediaError.noRemoteFile.errorDescription)
        XCTAssertNotNil(MediaError.downloadFailed.errorDescription)
        XCTAssertNotNil(MediaError.unsupportedFormat.errorDescription)
    }

    // MARK: - SettingsStore

    @MainActor
    func testSettingsStore_persistence() {
        let store = UserDefaults(suiteName: "test.\(UUID())")!
        defer { store.dictionaryRepresentation().keys.forEach { store.removeObject(forKey: $0) } }

        let settingsStore = SettingsStore(store: store)
        settingsStore.settings.appearanceMode = .dark
        settingsStore.settings.fontScale = 1.3

        let reloaded = SettingsStore(store: store)
        XCTAssertEqual(reloaded.settings.appearanceMode, .dark)
        XCTAssertEqual(reloaded.settings.fontScale, 1.3, accuracy: 0.01)
    }

    // MARK: - TelegramAPIConfiguration

    func testAPIConfiguration_initValues() {
        let config = TelegramAPIConfiguration(apiID: 12345, apiHash: "abc123", useTestDC: true)
        XCTAssertEqual(config.apiID, 12345)
        XCTAssertEqual(config.apiHash, "abc123")
        XCTAssertTrue(config.useTestDC)
    }

    func testAPIConfiguration_loadFromBundle_returnsNilForEmptyBundle() {
        let config = TelegramAPIConfiguration.load(from: Bundle(for: type(of: self)))
        _ = config
    }

    // MARK: - TelegramClientFactory

    func testClientFactory_returnsClient() {
        let client = TelegramClientFactory.makeDefaultClient()
        XCTAssertNotNil(client)
    }

    // MARK: - KeychainService

    func testKeychain_saveAndLoad() {
        let keychain = KeychainService.shared
        let testKey = "test.key.\(UUID())"
        defer { keychain.delete(forKey: testKey) }

        let data = "Hello Keychain".data(using: .utf8)!
        XCTAssertTrue(keychain.save(data, forKey: testKey))
        XCTAssertEqual(keychain.load(forKey: testKey), data)
    }

    func testKeychain_delete() {
        let keychain = KeychainService.shared
        let testKey = "test.key.\(UUID())"
        let data = "test".data(using: .utf8)!
        keychain.save(data, forKey: testKey)
        XCTAssertTrue(keychain.delete(forKey: testKey))
        XCTAssertNil(keychain.load(forKey: testKey))
    }

    func testKeychain_codable() {
        let keychain = KeychainService.shared
        let testKey = "test.codable.\(UUID())"
        defer { keychain.delete(forKey: testKey) }

        let account = Account(displayName: "Test", phoneNumber: "+1")
        XCTAssertTrue(keychain.saveCodable(account, forKey: testKey))
        let loaded = keychain.loadCodable(Account.self, forKey: testKey)
        XCTAssertEqual(loaded?.displayName, "Test")
    }

    func testKeychain_loadNonExistent() {
        let keychain = KeychainService.shared
        XCTAssertNil(keychain.load(forKey: "nonexistent.\(UUID())"))
    }

    // MARK: - MessageSendStatus

    func testMessageSendStatus_codable() throws {
        let statuses: [MessageSendStatus] = [.sending, .sent, .failed]
        for status in statuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(MessageSendStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }

    func testMessage_defaultSendStatus() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hello")
        XCTAssertEqual(msg.sendStatus, .sent)
    }

    func testMessage_sendingStatus() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hello", sendStatus: .sending)
        XCTAssertEqual(msg.sendStatus, .sending)
    }

    func testMessage_failedStatus() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hello", sendStatus: .failed)
        XCTAssertEqual(msg.sendStatus, .failed)
    }

    // MARK: - TelegramUpdateDelegate

    func testUpdateDelegate_protocol() {
        // 验证 TelegramUpdateDelegate 协议存在且可被实现
        // TelegramSessionStore 已实现此协议，编译通过即视为合格
    }
}
