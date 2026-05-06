import SwiftUI
import BZGramCore

public struct AuthenticationView: View {

    @EnvironmentObject private var sessionStore: TelegramSessionStore

    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var password = ""

    /// 输入框焦点管理
    enum Field: Hashable {
        case phone, code, password
    }
    @FocusState private var focusedField: Field?

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
                    // 初始聚焦手机号
                    if sessionStore.authorizationState == .waitingForPhoneNumber {
                        focusedField = .phone
                    }
                }
            }
            .onChange(of: sessionStore.authorizationState) { newState in
                // 状态变更时自动切换焦点
                switch newState {
                case .waitingForPhoneNumber:
                    focusedField = .phone
                case .waitingForCode:
                    focusedField = .code
                    verificationCode = "" // 进入验证码页清空旧验证码
                case .waitingForPassword:
                    focusedField = .password
                    password = ""
                case .ready:
                    focusedField = nil
                    // 登录成功清空手机号
                    phoneNumber = ""
                default:
                    break
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Telegram 登录")
                .font(.largeTitle.bold())
            Text("请确保已配置 Telegram API 参数，否则登录将无法连接。")
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
                .keyboardType(.default) // 改为默认键盘，支持用户自定义键盘（搜狗等）
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .phone)
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
            .disabled(sessionStore.isBusy || phoneNumber.isEmpty)
        }
    }

    private func codeForm(phoneNumber: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("验证码已发送到 \(phoneNumber)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("返回修改") {
                    sessionStore.backToPhoneNumber()
                }
                .font(.subheadline)
            }
            TextField("验证码", text: $verificationCode)
                .textContentType(.oneTimeCode) // 支持短信验证码自动填充
                .keyboardType(.numbersAndPunctuation) // 诱导第三方键盘弹出数字模式
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .code)
            HStack {
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
                .disabled(sessionStore.isBusy || verificationCode.isEmpty)

                Button {
                    Task { await sessionStore.resendAuthenticationCode() }
                } label: {
                    Text("重新发送")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(sessionStore.isBusy)
            }
        }
    }

    private func passwordForm(hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(hint ?? "请输入你的两步验证密码")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("返回修改") {
                    sessionStore.backToPhoneNumber()
                }
                .font(.subheadline)
            }
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    Task { await sessionStore.submitPassword(password) }
                }
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
            .disabled(sessionStore.isBusy || password.isEmpty)
        }
    }

    private var readyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("已登录：\(sessionStore.currentUser?.displayName ?? "Telegram 用户")", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("认证完成。现在可以进入聊天和设置。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
