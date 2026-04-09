import SwiftUI
import BZGramCore

/// Language picker + translation toggle for a single conversation.
/// Changes here override the global translation setting for this chat only.
public struct ConversationTranslationSettingsView: View {

    let chat: Chat
    @ObservedObject var chatListViewModel: ChatListViewModel
    @Environment(\.dismiss) private var dismiss

    // Local editable state, seeded from the existing override (if any).
    @State private var enabled: Bool
    @State private var selectedLanguageCode: String
    @State private var showOriginal: Bool
    @State private var useGlobal: Bool

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

    public init(chat: Chat, chatListViewModel: ChatListViewModel) {
        self.chat = chat
        self.chatListViewModel = chatListViewModel
        let override = chat.translationOverride
        _useGlobal          = State(initialValue: override == nil)
        _enabled            = State(initialValue: override?.autoTranslateEnabled ?? false)
        _selectedLanguageCode = State(initialValue: override?.targetLanguageCode ?? "en")
        _showOriginal       = State(initialValue: override?.showOriginalText ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use global setting", isOn: $useGlobal)
                }

                if !useGlobal {
                    Section("Translation") {
                        Toggle("Auto-translate", isOn: $enabled)

                        if enabled {
                            Picker("Target language", selection: $selectedLanguageCode) {
                                ForEach(supportedLanguages, id: \.code) { lang in
                                    Text(lang.name).tag(lang.code)
                                }
                            }

                            Toggle("Show original text", isOn: $showOriginal)
                        }
                    }
                }
            }
            .navigationTitle("Translation – \(chat.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        if useGlobal {
            chatListViewModel.clearTranslationOverride(for: chat)
        } else {
            let newSettings = TranslationSettings(
                targetLanguageCode: enabled ? selectedLanguageCode : nil,
                autoTranslateEnabled: enabled,
                showOriginalText: showOriginal
            )
            chatListViewModel.setTranslationOverride(newSettings, for: chat)
        }
        dismiss()
    }
}
