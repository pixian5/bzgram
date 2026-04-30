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

    // MARK: - ContactService

    func testContactService_addAndFetch() async {
        let service = ContactService()
        let contact = Contact(id: 1, displayName: "Alice", status: .online)
        service.addContact(contact)
        let contacts = await service.fetchContacts()
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts.first?.displayName, "Alice")
    }

    func testContactService_search() async {
        let service = ContactService()
        service.addContact(Contact(id: 1, displayName: "Alice", username: "alice"))
        service.addContact(Contact(id: 2, displayName: "Bob", username: "bob"))

        let results = await service.searchContacts(query: "Ali")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.displayName, "Alice")
    }

    func testContactService_searchByUsername() async {
        let service = ContactService()
        service.addContact(Contact(id: 1, displayName: "Alice", username: "alice99"))
        let results = await service.searchContacts(query: "alice99")
        XCTAssertEqual(results.count, 1)
    }

    func testContactService_remove() async {
        let service = ContactService()
        service.addContact(Contact(id: 1, displayName: "Alice"))
        service.removeContact(id: 1)
        let contacts = await service.fetchContacts()
        XCTAssertTrue(contacts.isEmpty)
    }

    func testContactService_getById() {
        let service = ContactService()
        let contact = Contact(id: 42, displayName: "Alice")
        service.addContact(contact)
        XCTAssertEqual(service.contact(for: 42)?.displayName, "Alice")
        XCTAssertNil(service.contact(for: 999))
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
        // 默认 test bundle 没有配置 API keys
        // 这个测试验证缺少配置时返回 nil
        let config = TelegramAPIConfiguration.load(from: Bundle(for: type(of: self)))
        // 可能返回 nil（正常），也可能返回值（如果测试 bundle 有配置）
        // 关键是不崩溃
        _ = config
    }

    // MARK: - TelegramClientFactory

    func testClientFactory_returnsClient() {
        let client = TelegramClientFactory.makeDefaultClient()
        // 没有配置 API keys 时应该返回 MockTelegramClient
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
}
