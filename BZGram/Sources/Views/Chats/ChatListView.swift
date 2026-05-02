import SwiftUI
import BZGramCore

/// 聊天列表视图，支持搜索、过滤、右滑操作
public struct ChatListView: View {

    @ObservedObject var viewModel: ChatListViewModel
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sessionStore: TelegramSessionStore

    public init(viewModel: ChatListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    loadingState
                } else if viewModel.filteredChats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle(accountManager.activeAccount?.displayName ?? "聊天")
            .searchable(text: $viewModel.searchQuery, prompt: "搜索聊天")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    advancedFilterMenu
                }
            }
            .task {
                guard let account = accountManager.activeAccount else { return }
                await viewModel.loadChats(for: account)
            }
            .refreshable {
                guard accountManager.activeAccount != nil else { return }
                await sessionStore.refreshChats()
                viewModel.chats = sessionStore.chats
            }
        }
    }

    // MARK: - 过滤菜单

    private var filterMenu: some View {
        Menu {
            ForEach(ChatListViewModel.ChatFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation { viewModel.selectedFilter = filter }
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if viewModel.selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var advancedFilterMenu: some View {
        Menu {
            Toggle(isOn: $viewModel.showTranslatedOnly) {
                Label("只看翻译中的聊天", systemImage: "globe")
            }
            Toggle(isOn: $viewModel.showPinnedOnly) {
                Label("只看置顶聊天", systemImage: "pin")
            }
            Toggle(isOn: $viewModel.showMutedOnly) {
                Label("只看静音聊天", systemImage: "bell.slash")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }

    // MARK: - 聊天列表

    private var chatList: some View {
        List {
            ForEach(viewModel.filteredChats) { chat in
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteChat(chat) }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        Task { await viewModel.toggleMute(for: chat) }
                    } label: {
                        Label(chat.isMuted ? "取消静音" : "静音",
                              systemImage: chat.isMuted ? "bell.fill" : "bell.slash.fill")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await viewModel.markAsRead(chat) }
                    } label: {
                        Label("已读", systemImage: "envelope.open")
                    }
                    .tint(.blue)
                    Button {
                        Task { await viewModel.togglePin(for: chat) }
                    } label: {
                        Label(chat.isPinned ? "取消置顶" : "置顶",
                              systemImage: chat.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.purple)
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredChats.map(\.id))
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载聊天中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空状态

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                viewModel.searchQuery.isEmpty ? "暂无聊天" : "未找到结果",
                systemImage: viewModel.searchQuery.isEmpty ? "message" : "magnifyingglass",
                description: Text(viewModel.searchQuery.isEmpty
                    ? "你的聊天会显示在这里。"
                    : "尝试其他搜索关键词。")
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "message")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("暂无聊天")
                    .font(.headline)
                Text("你的聊天会显示在这里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 聊天行视图

private struct ChatRowView: View {
    let chat: Chat
    let effectiveSettings: TranslationSettings

    var body: some View {
        HStack(spacing: 12) {
            chatIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(chat.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let date = chat.lastMessageDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    if let sender = chat.lastMessageSenderName {
                        Text(sender + ":")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(chat.lastMessageSnippet ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                chat.isMuted ? Color.gray : Color.accentColor,
                                in: Capsule()
                            )
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
        .padding(.vertical, 4)
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
