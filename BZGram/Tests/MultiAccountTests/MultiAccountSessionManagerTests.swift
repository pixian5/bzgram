import XCTest
@testable import BZGramCore

@MainActor
final class MultiAccountSessionManagerTests: XCTestCase {

    private var accountManager: AccountManager!
    private var sut: MultiAccountSessionManager!
    private var store: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        let suiteName = "BZGramTests.MultiAccount.\(UUID())"
        store = UserDefaults(suiteName: suiteName)!
        accountManager = AccountManager(store: store)
        sut = MultiAccountSessionManager(accountManager: accountManager)
    }

    override func tearDown() async throws {
        store.dictionaryRepresentation().keys.forEach { store.removeObject(forKey: $0) }
        sut = nil
        accountManager = nil
        store = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialState_noAccounts_activeSessionIsNil() {
        XCTAssertNil(sut.activeSession)
    }

    // MARK: - Adding accounts

    func testAddFirstAccount_createsActiveSession() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        XCTAssertNotNil(sut.activeSession)
    }

    func testAddMultipleAccounts_onlyFirstBecomesActive() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let firstSession = sut.activeSession

        sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")

        XCTAssertTrue(sut.activeSession === firstSession,
                      "Active session should remain the first account's after adding a second account")
    }

    func testAddAccount_registersInAccountManager() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        XCTAssertEqual(accountManager.accounts.count, 1)
        XCTAssertEqual(accountManager.accounts.first?.displayName, "Alice")
    }

    // MARK: - Switching accounts

    func testSwitchToAccount_changesActiveSession() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let aliceSession = sut.activeSession

        let bob = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        sut.switchToAccount(bob)

        XCTAssertFalse(sut.activeSession === aliceSession,
                       "Active session should change after switching accounts")
    }

    func testSwitchToAccount_updatesAccountManagerActiveAccount() {
        sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let bob = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        sut.switchToAccount(bob)

        XCTAssertEqual(accountManager.activeAccount?.displayName, "Bob")
    }

    func testSwitchBackToOriginalAccount_restoresSameSessionInstance() {
        let alice = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let aliceSession = sut.activeSession

        let bob = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        sut.switchToAccount(bob)
        sut.switchToAccount(alice)

        XCTAssertTrue(sut.activeSession === aliceSession,
                      "Switching back to Alice should return the same cached session")
    }

    // MARK: - Session-per-account isolation

    func testSessionForAccount_returnsSameInstanceOnMultipleCalls() {
        let alice = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let s1 = sut.session(for: alice)
        let s2 = sut.session(for: alice)
        XCTAssertTrue(s1 === s2, "session(for:) must return the same cached instance")
    }

    func testTwoAccounts_haveDifferentSessions() {
        let alice = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let bob = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")

        let aliceSession = sut.session(for: alice)
        let bobSession = sut.session(for: bob)

        XCTAssertFalse(aliceSession === bobSession,
                       "Different accounts must have independent session stores")
    }

    // MARK: - Removing accounts

    func testRemoveAccount_activeSessionFallsBackToNext() async {
        let alice = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        let bob = sut.addAccount(displayName: "Bob", phoneNumber: "+10000000002")
        sut.switchToAccount(alice)

        await sut.removeAccount(alice)

        // After removing Alice the active account/session should be Bob's.
        XCTAssertEqual(accountManager.activeAccount?.displayName, "Bob")
        XCTAssertNotNil(sut.activeSession)
        _ = bob  // suppress unused warning
    }

    func testRemoveOnlyAccount_activeSessionBecomesNil() async {
        let alice = sut.addAccount(displayName: "Alice", phoneNumber: "+10000000001")
        await sut.removeAccount(alice)

        XCTAssertNil(sut.activeSession)
        XCTAssertTrue(accountManager.accounts.isEmpty)
    }

    // MARK: - Unlimited accounts

    func testAddManyAccounts_noLimit() {
        for i in 1...50 {
            sut.addAccount(displayName: "User \(i)", phoneNumber: "+1000000\(String(format: "%04d", i))")
        }
        XCTAssertEqual(accountManager.accounts.count, 50)
    }
}
