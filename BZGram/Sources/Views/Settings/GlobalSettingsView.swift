import SwiftUI
import BZGramCore

/// Global app settings: auto-translation defaults that apply to all conversations
/// unless a per-conversation override is in place.
public struct GlobalSettingsView: View {

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var multiAccountManager: MultiAccountSessionManager

    private let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("pt", "Portuguese"),
        ("it", "Italian"),
        ("nl", "Dutch"),
        ("tr", "Turkish"),
        ("vi", "Vietnamese"),
        ("th", "Thai"),
        ("pl", "Polish"),
        ("hi", "Hindi"),
        ("id", "Indonesian"),
        ("uk", "Ukrainian")
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Profile section
                if let user = multiAccountManager.activeSession?.currentUser {
                    Section("Profile") {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(Color.accentColor)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.body.bold())
                                Text(user.phoneNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Translation section
                Section {
                    Toggle(
                        "Auto-translate all chats",
                        isOn: Binding(
                            get: { settingsStore.settings.globalTranslation.autoTranslateEnabled },
                            set: { settingsStore.settings.globalTranslation.autoTranslateEnabled = $0 }
                        )
                    )

                    if settingsStore.settings.globalTranslation.autoTranslateEnabled {
                        Picker(
                            "Target language",
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
                            "Show original text",
                            isOn: Binding(
                                get: { settingsStore.settings.globalTranslation.showOriginalText },
                                set: { settingsStore.settings.globalTranslation.showOriginalText = $0 }
                            )
                        )
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("These settings apply to every conversation. You can override them per chat via the globe icon inside any conversation.")
                }

                // MARK: About section
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Platform", value: "iOS")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
