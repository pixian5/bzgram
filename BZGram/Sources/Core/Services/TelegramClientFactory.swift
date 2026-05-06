import Foundation

public enum TelegramClientFactory {

    public static func makeDefaultClient(bundle: Bundle = .main) -> TelegramClient {
        guard let configuration = TelegramAPIConfiguration.load(from: bundle) else {
            print("⚠️ [BZGram] Telegram API Configuration not found! Falling back to MOCK MODE.")
            return MockTelegramClient()
        }
        print("✅ [BZGram] Telegram API Configuration loaded. Using REAL TDLib MODE.")
        return TDLibTelegramClient(configuration: configuration)
    }
}
