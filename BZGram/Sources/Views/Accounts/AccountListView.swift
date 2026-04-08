import SwiftUI

/// Displays all accounts and lets the user add or switch between them.
/// There is no cap on how many accounts can be added.
public struct AccountListView: View {

    @ObservedObject var viewModel: AccountListViewModel
    @State private var showAddAccount = false
    @State private var newDisplayName = ""
    @State private var newPhoneNumber = ""

    public init(viewModel: AccountListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
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
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddAccount = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                addAccountSheet
            }
        }
    }

    // MARK: - Add account sheet

    private var addAccountSheet: some View {
        NavigationStack {
            Form {
                Section("Account details") {
                    TextField("Display name", text: $newDisplayName)
                    TextField("Phone number", text: $newPhoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddAccount = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newDisplayName.trimmingCharacters(in: .whitespaces)
                        let phone = newPhoneNumber.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, !phone.isEmpty else { return }
                        viewModel.addAccount(displayName: name, phoneNumber: phone)
                        newDisplayName = ""
                        newPhoneNumber = ""
                        showAddAccount = false
                    }
                }
            }
        }
    }
}

// MARK: - Account row

private struct AccountRowView: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    let onLogout: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(account.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                Text(account.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if account.isAuthenticated {
                    Text("Connected")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text("Not logged in")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
            Button(action: onLogout) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .tint(.orange)
        }
    }
}
