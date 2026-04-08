import XCTest
@testable import BZGramCore

final class AccountManagerTests: XCTestCase {

    private var sut: AccountManager!
    private var store: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use an isolated UserDefaults suite so tests don't pollute the real store.
        let suiteName = "BZGramTests.AccountManager.\(UUID())"
        store = UserDefaults(suiteName: suiteName)!
        sut = AccountManager(store: store)
    }

    override func tearDown() {
        // Clean up the isolated suite by removing all keys manually.
        store.dictionaryRepresentation().keys.forEach { store.removeObject(forKey: $0) }
        sut = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Adding accounts

    func testAddFirstAccount_setsItAsActive() {
        let account = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        XCTAssertEqual(sut.accounts.count, 1)
        XCTAssertEqual(sut.activeAccount?.id, account.id)
    }

    func testAddMultipleAccounts_noLimit() {
        // Verify there is no cap by adding 100 accounts.
        for i in 1...100 {
            sut.addAccount(displayName: "User \(i)", phoneNumber: "+1000000\(String(format: "%04d", i))")
        }
        XCTAssertEqual(sut.accounts.count, 100)
    }

    func testAddSecondAccount_doesNotChangeActiveAccount() {
        let first  = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        _           = sut.addAccount(displayName: "Bob",   phoneNumber: "+10000000002")
        XCTAssertEqual(sut.activeAccount?.id, first.id)
    }

    // MARK: - Removing accounts

    func testRemoveAccount_removesFromList() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        sut.removeAccount(a.id)
        XCTAssertTrue(sut.accounts.isEmpty)
    }

    func testRemoveActiveAccount_fallsBackToNextAuthenticated() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let b = sut.addAccount(displayName: "Bob",   phoneNumber: "+10000000002")
        sut.markAuthenticated(b.id)
        sut.setActive(a)
        sut.removeAccount(a.id)
        XCTAssertEqual(sut.activeAccount?.id, b.id)
    }

    // MARK: - Authentication state

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
    }

    // MARK: - Persistence

    func testPersistence_accountsSurviveReinitialization() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        sut.addAccount(displayName: "Bob",   phoneNumber: "+10000000002")

        let reloaded = AccountManager(store: store)
        XCTAssertEqual(reloaded.accounts.count, 2)
    }

    func testPersistence_activeAccountSurvivesReinitialization() {
        let a = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let b = sut.addAccount(displayName: "Bob",   phoneNumber: "+10000000002")
        sut.setActive(b)

        let reloaded = AccountManager(store: store)
        XCTAssertEqual(reloaded.activeAccount?.id, b.id)
        XCTAssertNotEqual(reloaded.activeAccount?.id, a.id)
    }
}
