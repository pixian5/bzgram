import SwiftUI
import BZGramCore

/// BZGram application entry point.
@main
public struct BZGramApp: App {

    @StateObject private var accountManager: AccountManager
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var multiAccountManager: MultiAccountSessionManager

    public init() {
        let accountManager = AccountManager()
        let settingsStore = SettingsStore()
        let multiAccountManager = MultiAccountSessionManager(accountManager: accountManager)

        _accountManager = StateObject(wrappedValue: accountManager)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _multiAccountManager = StateObject(wrappedValue: multiAccountManager)
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountManager)
                .environmentObject(settingsStore)
                .environmentObject(multiAccountManager)
        }
    }
}
