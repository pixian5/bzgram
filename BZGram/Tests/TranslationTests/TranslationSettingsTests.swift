import XCTest
@testable import BZGramCore

final class TranslationSettingsTests: XCTestCase {

    // MARK: - TranslationSettings model

    func testDisabledPreset() {
        let s = TranslationSettings.disabled
        XCTAssertFalse(s.autoTranslateEnabled)
    }

    func testAutoTranslatePreset() {
        let s = TranslationSettings.autoTranslate(to: "fr", showOriginal: false)
        XCTAssertTrue(s.autoTranslateEnabled)
        XCTAssertEqual(s.targetLanguageCode, "fr")
        XCTAssertFalse(s.showOriginalText)
    }

    func testCodingRoundTrip() throws {
        let original = TranslationSettings(targetLanguageCode: "zh-Hans", autoTranslateEnabled: true, showOriginalText: false)
        let data   = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Chat.effectiveTranslation

    func testChatWithNoOverride_usesGlobal() {
        let global = TranslationSettings.autoTranslate(to: "en")
        let chat = Chat(id: 1, title: "Test", translationOverride: nil)
        XCTAssertEqual(chat.effectiveTranslation(globalSettings: global), global)
    }

    func testChatWithOverride_usesOverride() {
        let global   = TranslationSettings.autoTranslate(to: "en")
        let override = TranslationSettings.autoTranslate(to: "de", showOriginal: false)
        let chat = Chat(id: 1, title: "Test", translationOverride: override)
        let effective = chat.effectiveTranslation(globalSettings: global)
        XCTAssertEqual(effective.targetLanguageCode, "de")
        XCTAssertFalse(effective.showOriginalText)
    }

    // MARK: - Message.displayText

    func testDisplayText_withTranslationDisabled_returnsOriginal() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola", translatedText: "Hello")
        XCTAssertEqual(msg.displayText(settings: .disabled), "Hola")
    }

    func testDisplayText_withTranslationEnabled_returnsTranslation() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola", translatedText: "Hello")
        XCTAssertEqual(msg.displayText(settings: .autoTranslate(to: "en")), "Hello")
    }

    func testDisplayText_withTranslationEnabled_noTranslation_returnsOriginal() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola", translatedText: nil)
        XCTAssertEqual(msg.displayText(settings: .autoTranslate(to: "en")), "Hola")
    }

    // MARK: - TranslationService (stub)

    func testTranslationService_stubReturnsOriginal() async {
        let service = TranslationService.shared
        let result = await service.translate("Hola", to: "en")
        XCTAssertEqual(result, "Hola")
    }

    func testTranslationService_batchPreservesOrder() async {
        let service = TranslationService.shared
        let messages = (1...10).map {
            Message(id: Int64($0), chatID: 1, senderName: "A", originalText: "msg \($0)")
        }
        let settings = TranslationSettings.autoTranslate(to: "en")
        let translated = await service.translateMessages(messages, settings: settings)
        XCTAssertEqual(translated.map(\.id), messages.map(\.id))
    }

    func testTranslationService_disabledReturnsInputUnchanged() async {
        let service = TranslationService.shared
        let messages = [Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola")]
        let result = await service.translateMessages(messages, settings: .disabled)
        XCTAssertNil(result.first?.translatedText)
    }

    // MARK: - AppSettings persistence

    func testAppSettingsPersistence() throws {
        let store = UserDefaults(suiteName: "BZGramTests.AppSettings.\(UUID())")!
        defer {
            store.dictionaryRepresentation().keys.forEach { store.removeObject(forKey: $0) }
        }

        let settingsStore = SettingsStore(store: store)
        settingsStore.settings.globalTranslation = .autoTranslate(to: "ja", showOriginal: false)

        let reloaded = SettingsStore(store: store)
        XCTAssertTrue(reloaded.settings.globalTranslation.autoTranslateEnabled)
        XCTAssertEqual(reloaded.settings.globalTranslation.targetLanguageCode, "ja")
        XCTAssertFalse(reloaded.settings.globalTranslation.showOriginalText)
    }
}
