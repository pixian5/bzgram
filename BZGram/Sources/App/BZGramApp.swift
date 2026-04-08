import SwiftUI

/// BZGram application entry point.
@main
public struct BZGramApp: App {

    @StateObject private var accountManager = AccountManager()
    @StateObject private var settingsStore  = SettingsStore()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountManager)
                .environmentObject(settingsStore)
        }
    }
}
