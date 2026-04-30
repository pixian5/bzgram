import SwiftUI
import BZGramCore

/// Lists all chats for the active account.
public struct ChatListView: View {

    @ObservedObject var viewModel: ChatListViewModel
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var multiAccountManager: MultiAccountSessionManager

    public init(viewModel: ChatListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading chats…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.chats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle(accountManager.activeAccount?.displayName ?? "Chats")
            .task {
                guard let account = accountManager.activeAccount else { return }
                await viewModel.loadChats(for: account)
            }
            .refreshable {
                guard accountManager.activeAccount != nil else { return }
                if let session = multiAccountManager.activeSession {
                    await session.refreshChats()
                    viewModel.chats = session.chats
                }
            }
        }
    }

    private var chatList: some View {
        List(viewModel.chats) { chat in
            NavigationLink {
                ChatView(
                    viewModel: ChatViewModel(chat: chat, settingsStore: settingsStore, sessionStore: sessionStore),
                    chatListViewModel: viewModel
                )
            } label: {
                ChatRowView(
                    chat: chat,
                    effectiveSettings: viewModel.effectiveSettings(for: chat)
                )
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No Chats",
                systemImage: "message",
                description: Text("Your conversations will appear here.")
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "message")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No Chats")
                    .font(.headline)
                Text("Your conversations will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}

// MARK: - Chat row

private struct ChatRowView: View {
    let chat: Chat
    let effectiveSettings: TranslationSettings

    var body: some View {
        HStack(spacing: 12) {
            chatIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(chat.title)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    if let date = chat.lastMessageDate {
                        Text(date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(chat.lastMessageSnippet ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }

                if effectiveSettings.autoTranslateEnabled {
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .imageScale(.small)
                        Text(effectiveSettings.targetLanguageCode ?? "auto")
                            .font(.caption2)
                    }
                    .foregroundStyle(chat.translationOverride != nil ? .purple : .blue)
                }
            }
        }
    }

    private var chatIcon: some View {
        let (icon, color): (String, Color) = {
            switch chat.type {
            case .private:    return ("person.fill", .accentColor)
            case .group:      return ("person.3.fill", .green)
            case .supergroup: return ("person.3.fill", .orange)
            case .channel:    return ("megaphone.fill", .red)
            }
        }()
        return Circle()
            .fill(color.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(Image(systemName: icon).foregroundStyle(color))
    }
}
