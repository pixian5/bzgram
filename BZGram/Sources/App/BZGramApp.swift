import SwiftUI
import BZGramCore

/// BZGram application entry point.
@main
public struct BZGramApp: App {

    @StateObject private var accountManager = AccountManager()
    @StateObject private var settingsStore  = SettingsStore()
    @StateObject private var sessionStore: TelegramSessionStore

    public init() {
        let accountManager = AccountManager()
        _accountManager = StateObject(wrappedValue: accountManager)
        _settingsStore = StateObject(wrappedValue: SettingsStore())
        _sessionStore = StateObject(
            wrappedValue: TelegramSessionStore(
                client: TelegramClientFactory.makeDefaultClient(),
                accountManager: accountManager
            )
        )
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountManager)
                .environmentObject(settingsStore)
                .environmentObject(sessionStore)
        }
    }
}
