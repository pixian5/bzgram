import SwiftUI
import BZGramCore

/// 账号管理列表视图
public struct AccountListView: View {

    @ObservedObject var viewModel: AccountListViewModel
    @State private var showAddAccount = false

    public init(viewModel: AccountListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.accounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle("账号管理")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddAccount = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.totalCount > 0 {
                        Text("\(viewModel.authenticatedCount)/\(viewModel.totalCount) 已连接")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(viewModel: viewModel)
            }
        }
    }

    private var accountList: some View {
        List {
            ForEach(viewModel.accounts) { account in
                AccountRowView(
                    account: account,
                    isActive: account.id == viewModel.activeAccount?.id,
                    onSelect: { viewModel.selectAccount(account) },
                    onLogout: { viewModel.logoutAccount(account) },
                    onRemove: { viewModel.removeAccount(account) }
                )
            }
            .onMove { source, destination in
                viewModel.moveAccount(from: source, to: destination)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.accentColor.opacity(0.6))
            Text("暂无账号")
                .font(.title3.weight(.semibold))
            Text("添加你的 Telegram 账号开始使用")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showAddAccount = true
            } label: {
                Label("添加账号", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 账号行视图

private struct AccountRowView: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    let onLogout: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isActive
                                ? [.accentColor, .accentColor.opacity(0.6)]
                                : [Color(.systemGray4), Color(.systemGray5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(account.initials)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(isActive ? .white : .primary)
                    )

                if isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(.white, lineWidth: 2)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(account.displayName)
                        .font(.body.weight(isActive ? .semibold : .regular))
                    if isActive {
                        Text("当前")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.accentColor, in: Capsule())
                    }
                }
                Text(account.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(account.isAuthenticated ? .green : .orange)
                        .frame(width: 6, height: 6)
                    Text(account.isAuthenticated ? "已连接" : "未登录")
                        .font(.caption2)
                        .foregroundStyle(account.isAuthenticated ? .green : .orange)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("移除", systemImage: "trash")
            }
            Button(action: onLogout) {
                Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .tint(.orange)
        }
        .accessibilityLabel("\(account.displayName), \(account.isAuthenticated ? "已连接" : "未登录")")
        .accessibilityHint(isActive ? "当前活跃账号" : "轻点切换到此账号")
    }
}
