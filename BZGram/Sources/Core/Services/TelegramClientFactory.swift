import Foundation

public enum TelegramClientFactory {

    /// Creates the default client using the app bundle's Info.plist configuration.
    /// Falls back to `MockTelegramClient` if API credentials are not configured.
    public static func makeDefaultClient(bundle: Bundle = .main) -> TelegramClient {
        guard let configuration = TelegramAPIConfiguration.load(from: bundle) else {
            return MockTelegramClient()
        }
        return TDLibTelegramClient(configuration: configuration)
    }

    /// Creates a client isolated to a specific account's on-disk storage.
    ///
    /// Each account gets its own TDLib database directory, so multiple accounts can
    /// be authenticated simultaneously without interfering with each other.
    ///
    /// - Parameters:
    ///   - account: The account this client will serve.
    ///   - bundle: Bundle used to read API credentials from Info.plist.
    /// - Returns: A `TDLibTelegramClient` keyed to the account, or a `MockTelegramClient`
    ///   if API credentials are absent.
    public static func makeClient(for account: Account, bundle: Bundle = .main) -> TelegramClient {
        guard let configuration = TelegramAPIConfiguration.load(from: bundle) else {
            return MockTelegramClient()
        }
        return TDLibTelegramClient(
            configuration: configuration,
            storageDirectoryName: account.id.uuidString
        )
    }
}
