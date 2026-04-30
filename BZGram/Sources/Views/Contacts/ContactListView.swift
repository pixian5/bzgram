import SwiftUI
import BZGramCore

/// 联系人列表视图
public struct ContactListView: View {

    @ObservedObject var viewModel: ContactListViewModel

    public init(viewModel: ContactListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.contacts.isEmpty {
                    ProgressView("加载联系人…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredContacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .navigationTitle("联系人")
            .searchable(text: $viewModel.searchQuery, prompt: "搜索联系人")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.onlineCount > 0 {
                        Text("\(viewModel.onlineCount) 人在线")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .task {
                await viewModel.loadContacts()
            }
        }
    }

    private var contactList: some View {
        List {
            ForEach(viewModel.groupedContacts, id: \.0) { section, contacts in
                Section(header: Text(section)) {
                    ForEach(contacts) { contact in
                        ContactRowView(contact: contact)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                viewModel.searchQuery.isEmpty ? "暂无联系人" : "未找到联系人",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text(viewModel.searchQuery.isEmpty
                    ? "你的 Telegram 联系人会显示在这里。"
                    : "尝试其他搜索关键词。")
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("暂无联系人")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 联系人行

private struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(contact.initials)
                    .font(.headline)
                    .foregroundStyle(.accentColor)
                // 在线状态指示器
                if contact.status == .online {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .offset(x: 16, y: 16)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body.weight(.medium))
                if let username = contact.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.accentColor)
                }
                Text(contact.statusText)
                    .font(.caption)
                    .foregroundStyle(contact.status == .online ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
