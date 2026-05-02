import SwiftUI
import BZGramCore

/// BZGram 应用入口
@main
public struct BZGramApp: App {

    @StateObject private var accountManager: AccountManager
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var sessionStore: TelegramSessionStore
    @StateObject private var contactService: ContactService

    /// 全局异常捕获标记
    @State private var hasError = false

    public init() {
        let manager = AccountManager()
        let settings = SettingsStore()

        // 使用活跃账号的 TDLib 客户端
        let client = manager.activeClient
        let session = TelegramSessionStore(
            client: client,
            accountManager: manager
        )

        // 创建联系人服务（注入同一个 TelegramClient）
        let contacts = ContactService(client: client)

        // 配置 MediaService 的下载通道
        MediaService.shared.configure(client: client)

        _accountManager = StateObject(wrappedValue: manager)
        _settingsStore = StateObject(wrappedValue: settings)
        _sessionStore = StateObject(wrappedValue: session)
        _contactService = StateObject(wrappedValue: contacts)

        // 全局异常捕获
        setupGlobalExceptionHandler()
    }

    /// 应用锁定状态
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    public var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(accountManager)
                    .environmentObject(settingsStore)
                    .environmentObject(sessionStore)
                    .environmentObject(contactService)
                    .preferredColorScheme(
                        settingsStore.settings.appearanceMode == .system ? nil :
                        settingsStore.settings.appearanceMode == .dark ? .dark : .light
                    )
                    .blur(radius: (settingsStore.settings.appLock && !isUnlocked) ? 10 : 0)

                if settingsStore.settings.appLock && !isUnlocked {
                    AppLockView(isUnlocked: $isUnlocked)
                        .transition(.opacity)
                }

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
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background && settingsStore.settings.appLock {
                    isUnlocked = false
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
