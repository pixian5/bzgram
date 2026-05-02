import SwiftUI
import BZGramCore

/// 全局设置页面
public struct GlobalSettingsView: View {

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var sessionStore: TelegramSessionStore
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    private let supportedLanguages = TranslationService.supportedLanguages

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 外观
                Section {
                    Picker("外观模式", selection: Binding(
                        get: { settingsStore.settings.appearanceMode },
                        set: { settingsStore.settings.appearanceMode = $0 }
                    )) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    HStack {
                        Text("字体大小")
                        Slider(
                            value: Binding(
                                get: { settingsStore.settings.fontScale },
                                set: { settingsStore.settings.fontScale = $0 }
                            ),
                            in: 0.8...1.4,
                            step: 0.1
                        )
                        Text(String(format: "%.0f%%", settingsStore.settings.fontScale * 100))
                            .font(.caption)
                            .monospacedDigit()
                    }
                } header: {
                    Text("外观")
                }

                // MARK: 翻译
                Section {
                    Toggle(
                        "自动翻译所有聊天",
                        isOn: Binding(
                            get: { settingsStore.settings.globalTranslation.autoTranslateEnabled },
                            set: { settingsStore.settings.globalTranslation.autoTranslateEnabled = $0 }
                        )
                    )

                    if settingsStore.settings.globalTranslation.autoTranslateEnabled {
                        Picker(
                            "目标语言",
                            selection: Binding(
                                get: { settingsStore.settings.globalTranslation.targetLanguageCode ?? "en" },
                                set: { settingsStore.settings.globalTranslation.targetLanguageCode = $0 }
                            )
                        ) {
                            ForEach(supportedLanguages, id: \.code) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }

                        Toggle(
                            "显示原文",
                            isOn: Binding(
                                get: { settingsStore.settings.globalTranslation.showOriginalText },
                                set: { settingsStore.settings.globalTranslation.showOriginalText = $0 }
                            )
                        )
                    }

                    HStack {
                        Text("翻译缓存")
                        Spacer()
                        Text("\(TranslationService.shared.cacheCount) 条")
                            .foregroundStyle(.secondary)
                        Button("清除") {
                            TranslationService.shared.clearCache()
                            sessionStore.showToast("翻译缓存已清除")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("翻译")
                } footer: {
                    Text("全局设置对所有对话生效。你可以在对话内通过地球图标覆盖单个对话的翻译设置。")
                }

                Section {
                    Picker(
                        "摘要输出语言",
                        selection: Binding(
                            get: { settingsStore.settings.summaryLanguageCode ?? "zh-Hans" },
                            set: { settingsStore.settings.summaryLanguageCode = $0 }
                        )
                    ) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                } header: {
                    Text("摘要")
                } footer: {
                    Text("聊天摘要默认使用中文生成，再按这里的设置尝试翻译输出。")
                }

                // MARK: 高级特权
                Section {
                    Toggle(
                        "幽灵模式",
                        isOn: Binding(
                            get: { settingsStore.settings.ghostMode },
                            set: { settingsStore.settings.ghostMode = $0 }
                        )
                    )
                    Toggle(
                        "防撤回模式",
                        isOn: Binding(
                            get: { settingsStore.settings.antiDelete },
                            set: { settingsStore.settings.antiDelete = $0 }
                        )
                    )
                    Toggle(
                        "启动密码锁 (FaceID/TouchID)",
                        isOn: Binding(
                            get: { settingsStore.settings.appLock },
                            set: { settingsStore.settings.appLock = $0 }
                        )
                    )
                } header: {
                    Text("安全与高级特权")
                } footer: {
                    Text("幽灵模式将隐藏你的“正在输入”状态并停止发送已读回执；防撤回模式会在本地保留对方已撤回/删除的消息。密码锁将在下次启动时生效。")
                }

                // MARK: 通知
                Section("通知") {
                    Toggle("消息预览", isOn: Binding(
                        get: { settingsStore.settings.notificationPreview },
                        set: { settingsStore.settings.notificationPreview = $0 }
                    ))
                    Toggle("发送消息声音", isOn: Binding(
                        get: { settingsStore.settings.sendMessageSound },
                        set: { settingsStore.settings.sendMessageSound = $0 }
                    ))
                }

                // MARK: 存储
                Section("存储") {
                    HStack {
                        Text("媒体缓存")
                        Spacer()
                        Text(MediaService.shared.formattedCacheSize)
                            .foregroundStyle(.secondary)
                        Button("清除") {
                            MediaService.shared.clearCache()
                            sessionStore.showToast("媒体缓存已清除")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }

                // MARK: 关于
                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("平台", value: "iOS")
                    Button("隐私政策") { showPrivacyPolicy = true }
                    Button("用户协议") { showTermsOfService = true }
                }

                // MARK: 无障碍
                Section("无障碍") {
                    Text("BZGram 完整支持 VoiceOver 和动态字体。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
        }
    }
}

// MARK: - 隐私政策

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("隐私政策")
                        .font(.title.bold())
                    Text("最后更新：2025年1月")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Group {
                        sectionText("1. 信息收集",
                            "BZGram 不会收集或存储您的个人信息。所有通信数据通过 Telegram 的服务器传输，BZGram 作为第三方客户端不会拦截、存储或分析您的消息内容。")

                        sectionText("2. 账号数据",
                            "您的账号认证信息（手机号、会话令牌）安全存储在设备的 Keychain 中，不会上传到任何第三方服务器。")

                        sectionText("3. 翻译功能",
                            "当您使用自动翻译功能时，翻译请求通过 iOS 系统翻译框架处理，BZGram 不会将消息内容发送给任何第三方翻译服务。翻译缓存仅存储在本地设备上。")

                        sectionText("4. 数据安全",
                            "我们采用 iOS Keychain 加密存储敏感数据，确保即使设备丢失也不会泄露您的账号信息。")

                        sectionText("5. 联系方式",
                            "如有隐私相关问题，请联系 hqlak47@gmail.com。")
                    }
                }
                .padding()
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func sectionText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 用户协议

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("用户协议")
                        .font(.title.bold())
                    Text("最后更新：2025年1月")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Group {
                        sectionText("1. 服务描述",
                            "BZGram 是一款非官方的 Telegram 第三方客户端，提供多账号管理和自动翻译功能。使用本应用即表示您同意遵守 Telegram 的官方服务条款。")

                        sectionText("2. 账号使用",
                            "您有责任保管好自己的 Telegram 账号安全。BZGram 支持无限数量的账号登录，但每个账号必须是您合法拥有的。")

                        sectionText("3. 免责声明",
                            "BZGram 作为第三方客户端，不对 Telegram 服务的可用性、稳定性或数据安全承担责任。请遵守当地法律法规使用本应用。")

                        sectionText("4. 知识产权",
                            "BZGram 的源代码采用 MIT 许可证开源。Telegram 是 Telegram Messenger Inc. 的注册商标。")

                        sectionText("5. 协议变更",
                            "我们保留随时修改本协议的权利。重大变更会通过应用内通知告知用户。")
                    }
                }
                .padding()
            }
            .navigationTitle("用户协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func sectionText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary)
        }
    }
}
