import SwiftUI
import BZGramCore

/// Main tab bar shown after a successful login.
public struct MainTabView: View {

    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore

    public init() {}

    public var body: some View {
        TabView {
            ChatListView(
                viewModel: ChatListViewModel(settingsStore: settingsStore)
            )
            .tabItem {
                Label("Chats", systemImage: "message.fill")
            }

            AccountListView(
                viewModel: AccountListViewModel(manager: accountManager)
            )
            .tabItem {
                Label("Accounts", systemImage: "person.2.fill")
            }

            GlobalSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
