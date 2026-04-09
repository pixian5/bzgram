import SwiftUI
import BZGramCore

/// Root application view.
/// Shows the chat list when an account is active, or the account picker when none is.
public struct RootView: View {

    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore

    public init() {}

    public var body: some View {
        if accountManager.activeAccount != nil {
            MainTabView()
        } else {
            AccountListView(
                viewModel: AccountListViewModel(manager: accountManager)
            )
        }
    }
}
