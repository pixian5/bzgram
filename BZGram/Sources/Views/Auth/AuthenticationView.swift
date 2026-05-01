import SwiftUI
import BZGramCore

public struct AuthenticationView: View {

    @EnvironmentObject private var sessionStore: TelegramSessionStore

    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var password = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                header
                currentStepForm
                if let error = sessionStore.lastErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("登录")
            .task {
                if !sessionStore.isAuthorized {
                    await sessionStore.start()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Telegram 登录")
                .font(.largeTitle.bold())
            Text("没有配置 Telegram API 参数时会自动使用演示后端，默认验证码是 12345。配置完成后会自动切换到真实 TDLib 登录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var currentStepForm: some View {
        switch sessionStore.authorizationState {
        case .waitingForPhoneNumber:
            phoneForm
        case .waitingForCode(let phoneNumber):
            codeForm(phoneNumber: phoneNumber)
        case .waitingForPassword(_, let hint):
            passwordForm(hint: hint)
        case .ready:
            readyState
        case .loggingOut:
            ProgressView("正在退出…")
        }
    }

    private var phoneForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入 Telegram 手机号开始登录，不需要手动输入加号。")
                .foregroundStyle(.secondary)
            TextField("86 138 0013 8000", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await sessionStore.submitPhoneNumber(phoneNumber) }
            } label: {
                if sessionStore.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("继续")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionStore.isBusy)
        }
    }

    private func codeForm(phoneNumber: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("验证码已发送到 \(phoneNumber)，请查收。")
                .foregroundStyle(.secondary)
            TextField("12345", text: $verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await sessionStore.submitCode(verificationCode) }
            } label: {
                if sessionStore.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("验证")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionStore.isBusy)
        }
    }

    private func passwordForm(hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(hint ?? "请输入你的 Telegram 两步验证密码。")
                .foregroundStyle(.secondary)
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await sessionStore.submitPassword(password) }
            } label: {
                if sessionStore.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("解锁")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionStore.isBusy)
        }
    }

    private var readyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("已登录：\(sessionStore.currentUser?.displayName ?? "Telegram 用户")", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("认证完成。现在可以进入聊天、账号管理和设置页面。")
                .foregroundStyle(.secondary)
        }
    }
}
