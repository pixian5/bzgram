import SwiftUI
import BZGramCore

/// Main tab bar shown after a successful login.
public struct MainTabView: View {

    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var multiAccountManager: MultiAccountSessionManager

    public init() {}

    public var body: some View {
        // activeSession is guaranteed non-nil when MainTabView is shown (see RootView),
        // but we guard defensively to avoid a forced unwrap.
        if let sessionStore = multiAccountManager.activeSession {
            TabView {
                ChatListView(
                    viewModel: ChatListViewModel(settingsStore: settingsStore, sessionStore: sessionStore)
                )
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }

                AccountListView(
                    viewModel: AccountListViewModel(
                        manager: accountManager,
                        multiAccountManager: multiAccountManager
                    )
                )
                .tabItem {
                    Label("Accounts", systemImage: "person.2.fill")
                }

                GlobalSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") {
                        Task { await sessionStore.logOut() }
                    }
                }
            }
        }
    }
}
