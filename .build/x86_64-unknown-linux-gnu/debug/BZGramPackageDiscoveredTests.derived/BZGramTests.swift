import XCTest
@testable import BZGramTests

fileprivate extension AccountManagerTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__AccountManagerTests = [
        ("testAddFirstAccount_setsItAsActive", testAddFirstAccount_setsItAsActive),
        ("testAddMultipleAccounts_noLimit", testAddMultipleAccounts_noLimit),
        ("testAddSecondAccount_doesNotChangeActiveAccount", testAddSecondAccount_doesNotChangeActiveAccount),
        ("testLogout_clearsAuthState", testLogout_clearsAuthState),
        ("testMarkAuthenticated_updatesAccount", testMarkAuthenticated_updatesAccount),
        ("testPersistence_accountsSurviveReinitialization", testPersistence_accountsSurviveReinitialization),
        ("testPersistence_activeAccountSurvivesReinitialization", testPersistence_activeAccountSurvivesReinitialization),
        ("testRemoveAccount_removesFromList", testRemoveAccount_removesFromList),
        ("testRemoveActiveAccount_fallsBackToNextAuthenticated", testRemoveActiveAccount_fallsBackToNextAuthenticated)
    ]
}

fileprivate extension TranslationSettingsTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__TranslationSettingsTests = [
        ("testAppSettingsPersistence", testAppSettingsPersistence),
        ("testAutoTranslatePreset", testAutoTranslatePreset),
        ("testChatWithNoOverride_usesGlobal", testChatWithNoOverride_usesGlobal),
        ("testChatWithOverride_usesOverride", testChatWithOverride_usesOverride),
        ("testCodingRoundTrip", testCodingRoundTrip),
        ("testDisabledPreset", testDisabledPreset),
        ("testDisplayText_withTranslationDisabled_returnsOriginal", testDisplayText_withTranslationDisabled_returnsOriginal),
        ("testDisplayText_withTranslationEnabled_noTranslation_returnsOriginal", testDisplayText_withTranslationEnabled_noTranslation_returnsOriginal),
        ("testDisplayText_withTranslationEnabled_returnsTranslation", testDisplayText_withTranslationEnabled_returnsTranslation),
        ("testTranslationService_batchPreservesOrder", asyncTest(testTranslationService_batchPreservesOrder)),
        ("testTranslationService_disabledReturnsInputUnchanged", asyncTest(testTranslationService_disabledReturnsInputUnchanged)),
        ("testTranslationService_stubReturnsOriginal", asyncTest(testTranslationService_stubReturnsOriginal))
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __BZGramTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AccountManagerTests.__allTests__AccountManagerTests),
        testCase(TranslationSettingsTests.__allTests__TranslationSettingsTests)
    ]
}