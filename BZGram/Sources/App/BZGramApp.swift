import SwiftUI
import BZGramCore

/// BZGram 应用入口
@main
public struct BZGramApp: App {

    @StateObject private var accountManager = AccountManager()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var sessionStore: TelegramSessionStore

    /// 全局异常捕获标记
    @State private var hasError = false

    public init() {
        let accountManager = AccountManager()
        _accountManager = StateObject(wrappedValue: accountManager)
        _settingsStore = StateObject(wrappedValue: SettingsStore())

        // 使用活跃账号的 TDLib 客户端（如果有的话）
        let client = accountManager.activeClient
        _sessionStore = StateObject(
            wrappedValue: TelegramSessionStore(
                client: client,
                accountManager: accountManager
            )
        )

        // 全局异常捕获
        setupGlobalExceptionHandler()
    }

    public var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(accountManager)
                    .environmentObject(settingsStore)
                    .environmentObject(sessionStore)
                    .preferredColorScheme(
                        settingsStore.settings.appearanceMode == .system ? nil :
                        settingsStore.settings.appearanceMode == .dark ? .dark : .light
                    )

                // 全局 Toast
                if let toast = sessionStore.toastMessage {
                    VStack {
                        Spacer()
                        ToastView(message: toast)
                            .padding(.bottom, 80)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: sessionStore.toastMessage)
                    }
                }
            }
        }
    }

    /// 配置全局异常捕获
    private func setupGlobalExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let info = [
                "name": exception.name.rawValue,
                "reason": exception.reason ?? "unknown",
                "callStack": exception.callStackSymbols.joined(separator: "\n")
            ]
            if let data = try? JSONSerialization.data(withJSONObject: info),
               let crashLog = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(crashLog, forKey: "bzgram.lastCrash")
            }
        }
    }
}

// MARK: - Toast 视图

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}
