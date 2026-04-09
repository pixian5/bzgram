import Foundation

public enum TelegramClientFactory {

    public static func makeDefaultClient(bundle: Bundle = .main) -> TelegramClient {
        guard let configuration = TelegramAPIConfiguration.load(from: bundle) else {
            return MockTelegramClient()
        }
        return TDLibTelegramClient(configuration: configuration)
    }
}
