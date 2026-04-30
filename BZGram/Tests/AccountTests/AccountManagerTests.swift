import XCTest
@testable import BZGramCore

final class AccountManagerTests: XCTestCase {

    private var sut: AccountManager!
    private var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        keychain = .shared
        // 清空测试数据
        keychain.deleteAll()
        sut = AccountManager(keychain: keychain, legacyStore: UserDefaults(suiteName: "test.\(UUID())")!)
    }

    override func tearDown() {
        keychain.deleteAll()
        sut = nil
        keychain = nil
        super.tearDown()
    }

    // MARK: - 添加账号

    func testAddFirstAccount_setsItAsActive() {
        let account = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        XCTAssertEqual(sut.accounts.count, 1)
        XCTAssertEqual(sut.activeAccount?.id, account.id)
    }

    func testAddMultipleAccounts_noLimit() {
        for i in 1...100 {
            sut.addAccount(displayName: "User \(i)", phoneNumber: "+1000000\(String(format: "%04d", i))")
        }
        XCTAssertEqual(sut.accounts.count, 100)
    }

    func testAddSecondAccount_doesNotChangeActiveAccount() {
        let first = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        _ = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        XCTAssertEqual(sut.activeAccount?.id, first.id)
    }

    func testAccount_hasTdlibInstanceId() {
        let account = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        XCTAssertFalse(account.tdlibInstanceId.isEmpty)
    }

    func testAccount_tdlibInstanceId_isUnique() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let b = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        XCTAssertNotEqual(a.tdlibInstanceId, b.tdlibInstanceId)
    }

    // MARK: - 移除账号

    func testRemoveAccount_removesFromList() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        sut.removeAccount(a.id)
        XCTAssertTrue(sut.accounts.isEmpty)
    }

    func testRemoveActiveAccount_fallsBackToNextAuthenticated() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let b = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        sut.markAuthenticated(b.id)
        sut.setActive(a)
        sut.removeAccount(a.id)
        XCTAssertEqual(sut.activeAccount?.id, b.id)
    }

    // MARK: - 认证状态

    func testMarkAuthenticated_updatesAccount() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        sut.markAuthenticated(a.id, telegramUserID: 42, displayName: "Alice Updated")
        XCTAssertTrue(sut.accounts.first!.isAuthenticated)
        XCTAssertEqual(sut.accounts.first!.telegramUserID, 42)
        XCTAssertEqual(sut.accounts.first!.displayName, "Alice Updated")
    }

    func testLogout_clearsAuthState() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        sut.markAuthenticated(a.id)
        sut.logout(a.id)
        XCTAssertFalse(sut.accounts.first!.isAuthenticated)
        XCTAssertNil(sut.accounts.first!.telegramUserID)
    }

    // MARK: - 排序

    func testMoveAccount_updatesOrder() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+1")
        sut.addAccount(displayName: "Bob", phoneNumber: "+2")
        sut.addAccount(displayName: "Charlie", phoneNumber: "+3")

        sut.moveAccount(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(sut.accounts[0].displayName, "Charlie")
        XCTAssertEqual(sut.accounts[0].sortOrder, 0)
    }

    // MARK: - 账号模型

    func testAccount_initials_twoWords() {
        let account = Account(displayName: "John Doe", phoneNumber: "+1")
        XCTAssertEqual(account.initials, "JD")
    }

    func testAccount_initials_singleWord() {
        let account = Account(displayName: "Alice", phoneNumber: "+1")
        XCTAssertEqual(account.initials, "AL")
    }

    func testAccount_codable() throws {
        let original = Account(
            displayName: "Test",
            phoneNumber: "+123",
            isAuthenticated: true,
            sortOrder: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Account.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
