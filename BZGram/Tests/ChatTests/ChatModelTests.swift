import XCTest
@testable import BZGramCore

final class ChatModelTests: XCTestCase {

    // MARK: - Chat 模型

    func testChat_codable() throws {
        let original = Chat(
            id: 42,
            title: "Test Chat",
            type: .supergroup,
            unreadCount: 5,
            isPinned: true,
            isMuted: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Chat.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testChat_effectiveTranslation_noOverride() {
        let global = TranslationSettings.autoTranslate(to: "en")
        let chat = Chat(id: 1, title: "Test")
        XCTAssertEqual(chat.effectiveTranslation(globalSettings: global), global)
    }

    func testChat_effectiveTranslation_withOverride() {
        let global = TranslationSettings.autoTranslate(to: "en")
        let override = TranslationSettings.autoTranslate(to: "zh-Hans")
        let chat = Chat(id: 1, title: "Test", translationOverride: override)
        XCTAssertEqual(chat.effectiveTranslation(globalSettings: global).targetLanguageCode, "zh-Hans")
    }

    func testChat_systemIconName() {
        XCTAssertEqual(Chat(id: 1, title: "T", type: .private).systemIconName, "person.fill")
        XCTAssertEqual(Chat(id: 2, title: "T", type: .group).systemIconName, "person.3.fill")
        XCTAssertEqual(Chat(id: 3, title: "T", type: .channel).systemIconName, "megaphone.fill")
    }

    func testChat_isPinned_default() {
        let chat = Chat(id: 1, title: "Test")
        XCTAssertFalse(chat.isPinned)
        XCTAssertFalse(chat.isMuted)
        XCTAssertFalse(chat.isArchived)
    }

    // MARK: - Message 模型

    func testMessage_codable() throws {
        let original = Message(
            id: 100,
            chatID: 1,
            senderName: "Alice",
            originalText: "Hello",
            contentType: .photo,
            isEdited: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testMessage_displayText_disabled() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola", translatedText: "Hello")
        XCTAssertEqual(msg.displayText(settings: .disabled), "Hola")
    }

    func testMessage_displayText_enabled() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hola", translatedText: "Hello")
        XCTAssertEqual(msg.displayText(settings: .autoTranslate(to: "en")), "Hello")
    }

    func testMessage_isTextOnly() {
        let textMsg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hello")
        XCTAssertTrue(textMsg.isTextOnly)

        let photoMsg = Message(id: 2, chatID: 1, senderName: "A", originalText: "", contentType: .photo)
        XCTAssertFalse(photoMsg.isTextOnly)
    }

    func testMessage_formattedTime() {
        let msg = Message(id: 1, chatID: 1, senderName: "A", originalText: "Hello")
        // formattedTime 应该返回 HH:mm 格式
        XCTAssertFalse(msg.formattedTime.isEmpty)
        XCTAssertTrue(msg.formattedTime.contains(":"))
    }

    // MARK: - MessageContentType

    func testMessageContentType_codable() throws {
        let types: [MessageContentType] = [.text, .photo, .video, .document, .sticker, .voice, .animation, .location, .contact, .unsupported]
        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(MessageContentType.self, from: data)
            XCTAssertEqual(type, decoded)
        }
    }

    // MARK: - MessageAttachment

    func testMessageAttachment_codable() throws {
        let attachment = MessageAttachment(
            fileName: "test.jpg",
            mimeType: "image/jpeg",
            fileSize: 1024,
            width: 800,
            height: 600
        )
        let data = try JSONEncoder().encode(attachment)
        let decoded = try JSONDecoder().decode(MessageAttachment.self, from: data)
        XCTAssertEqual(attachment, decoded)
        XCTAssertEqual(decoded.fileName, "test.jpg")
        XCTAssertEqual(decoded.fileSize, 1024)
    }

    // MARK: - Contact 模型

    func testContact_codable() throws {
        let contact = Contact(
            id: 42,
            displayName: "John Doe",
            username: "johndoe",
            phoneNumber: "+123",
            status: .online
        )
        let data = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Contact.self, from: data)
        XCTAssertEqual(contact, decoded)
    }

    func testContact_initials() {
        XCTAssertEqual(Contact(id: 1, displayName: "John Doe").initials, "JD")
        XCTAssertEqual(Contact(id: 2, displayName: "Alice").initials, "AL")
    }

    func testContact_statusText() {
        let online = Contact(id: 1, displayName: "A", status: .online)
        XCTAssertEqual(online.statusText, "在线")

        let unknown = Contact(id: 2, displayName: "B", status: .unknown)
        XCTAssertEqual(unknown.statusText, "未知")
    }

    // MARK: - TelegramUser

    func testTelegramUser_equality() {
        let a = TelegramUser(id: 1, displayName: "Alice", phoneNumber: "+1")
        let b = TelegramUser(id: 1, displayName: "Alice", phoneNumber: "+1")
        XCTAssertEqual(a, b)
    }

    // MARK: - TelegramAuthorizationState

    func testAuthState_equality() {
        XCTAssertEqual(TelegramAuthorizationState.ready, .ready)
        XCTAssertEqual(TelegramAuthorizationState.waitingForPhoneNumber, .waitingForPhoneNumber)
        XCTAssertNotEqual(TelegramAuthorizationState.ready, .waitingForPhoneNumber)
    }

    // MARK: - TelegramClientError

    func testClientError_descriptions() {
        XCTAssertNotNil(TelegramClientError.invalidPhoneNumber.errorDescription)
        XCTAssertNotNil(TelegramClientError.invalidCode.errorDescription)
        XCTAssertNotNil(TelegramClientError.invalidPassword.errorDescription)
        XCTAssertNotNil(TelegramClientError.unauthorized.errorDescription)
        XCTAssertNotNil(TelegramClientError.chatNotFound.errorDescription)
        XCTAssertNotNil(TelegramClientError.messageNotFound.errorDescription)
        XCTAssertNotNil(TelegramClientError.networkError.errorDescription)
        XCTAssertNotNil(TelegramClientError.unknown("test").errorDescription)
    }
}
