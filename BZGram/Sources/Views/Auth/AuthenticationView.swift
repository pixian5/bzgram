import SwiftUI
import BZGramCore

public struct AuthenticationView: View {

    @EnvironmentObject private var multiAccountManager: MultiAccountSessionManager

    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var password = ""

    public init() {}

    /// The session to interact with during authentication.
    /// If no accounts exist yet, `MultiAccountSessionManager` creates one on demand
    /// when the user submits their phone number.
    private var sessionStore: TelegramSessionStore? {
        multiAccountManager.activeSession
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let session = sessionStore {
                    currentStepForm(session: session)
                    if let error = session.lastErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } else {
                    startForm
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Sign In")
            .task {
                if let session = sessionStore, !session.isAuthorized {
                    await session.start()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Telegram Client")
                .font(.largeTitle.bold())
            Text("没有配置 Telegram API 参数时会自动使用演示后端，默认验证码是 `12345`。配置完成后会自动切换到真实 TDLib 登录。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Shown before any account exists — lets the user enter a phone number to create the first session.
    private var startForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入 Telegram 手机号开始登录，不需要手动输入加号。")
                .foregroundStyle(.secondary)
            TextField("86 138 0013 8000", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
            Button {
                Task {
                    // Create a provisional account entry so a session is available.
                    multiAccountManager.addAccount(displayName: "New Account", phoneNumber: phoneNumber)
                    if let session = multiAccountManager.activeSession {
                        await session.start()
                        await session.submitPhoneNumber(phoneNumber)
                    }
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private func currentStepForm(session: TelegramSessionStore) -> some View {
        switch session.authorizationState {
        case .waitingForPhoneNumber:
            phoneForm(session: session)
        case .waitingForCode(let phoneNumber):
            codeForm(phoneNumber: phoneNumber, session: session)
        case .waitingForPassword(_, let hint):
            passwordForm(hint: hint, session: session)
        case .ready:
            readyState(session: session)
        case .loggingOut:
            ProgressView("Signing out…")
        }
    }

    private func phoneForm(session: TelegramSessionStore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入 Telegram 手机号开始登录，不需要手动输入加号。")
                .foregroundStyle(.secondary)
            TextField("86 138 0013 8000", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await session.submitPhoneNumber(phoneNumber) }
            } label: {
                if session.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isBusy)
        }
    }

    private func codeForm(phoneNumber: String, session: TelegramSessionStore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We sent a verification code to `\(phoneNumber)`.")
                .foregroundStyle(.secondary)
            TextField("12345", text: $verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await session.submitCode(verificationCode) }
            } label: {
                if session.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify Code")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isBusy)
        }
    }

    private func passwordForm(hint: String?, session: TelegramSessionStore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(hint ?? "Enter your Telegram two-step verification password.")
                .foregroundStyle(.secondary)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await session.submitPassword(password) }
            } label: {
                if session.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Unlock")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isBusy)
        }
    }

    private func readyState(session: TelegramSessionStore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Signed in as \(session.currentUser?.displayName ?? "Telegram User")", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("The authenticated app shell is ready. Continue into chats, accounts, and settings.")
                .foregroundStyle(.secondary)
        }
    }
}
