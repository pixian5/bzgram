import SwiftUI
import BZGramCore

/// 主标签栏视图
public struct MainTabView: View {

    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sessionStore: TelegramSessionStore
    @State private var selectedTab: Tab = .chats

    enum Tab: Hashable {
        case chats, contacts, accounts, settings
    }

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView(
                viewModel: ChatListViewModel(settingsStore: settingsStore, sessionStore: sessionStore)
            )
            .tabItem {
                Label("聊天", systemImage: "message.fill")
            }
            .tag(Tab.chats)
            .badge(sessionStore.chats.reduce(0) { $0 + $1.unreadCount })

            ContactListView(
                viewModel: ContactListViewModel()
            )
            .tabItem {
                Label("联系人", systemImage: "person.crop.circle")
            }
            .tag(Tab.contacts)

            AccountListView(
                viewModel: AccountListViewModel(manager: accountManager)
            )
            .tabItem {
                Label("账号", systemImage: "person.2.fill")
            }
            .tag(Tab.accounts)

            GlobalSettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .tint(.accentColor)
    }
}
