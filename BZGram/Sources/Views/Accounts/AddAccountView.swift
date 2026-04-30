import SwiftUI
import BZGramCore

/// 添加新账号的独立页面
public struct AddAccountView: View {

    @ObservedObject var viewModel: AccountListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var showError = false

    public init(viewModel: AccountListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 头像预览
                    HStack {
                        Spacer()
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(previewInitials)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .accentColor.opacity(0.3), radius: 10)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("账号信息") {
                    TextField("显示名称", text: $displayName)
                        .textContentType(.name)
                        .accessibilityLabel("显示名称输入框")

                    TextField("手机号（含国际区号）", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .accessibilityLabel("手机号输入框")
                }

                Section {
                    Text("添加后需要在登录界面完成 Telegram 认证。BZGram 支持无限数量的账号。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addAccount()
                    }
                    .fontWeight(.semibold)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var previewInitials: String {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func addAccount() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !phone.isEmpty else { return }
        viewModel.addAccount(displayName: name, phoneNumber: phone)
        dismiss()
    }
}
