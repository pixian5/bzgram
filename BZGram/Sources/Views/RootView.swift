import SwiftUI
import BZGramCore

/// Root application view.
/// Shows the authentication screen when no account is logged in,
/// or the main tab interface when an active session exists.
public struct RootView: View {

    @EnvironmentObject private var multiAccountManager: MultiAccountSessionManager

    public init() {}

    public var body: some View {
        if let activeSession = multiAccountManager.activeSession, activeSession.isAuthorized {
            MainTabView()
                // Recreate the main UI whenever the active account changes
                // so view-models pick up the new session.
                .id(multiAccountManager.accountManager.activeAccount?.id)
        } else {
            AuthenticationView()
        }
    }
}
