import SwiftUI

/// The conversation view for a single chat.
public struct ChatView: View {

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var chatListViewModel: ChatListViewModel
    @State private var showTranslationSettings = false

    public init(viewModel: ChatViewModel, chatListViewModel: ChatListViewModel) {
        self.viewModel = viewModel
        self.chatListViewModel = chatListViewModel
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageList
            }
        }
        .navigationTitle(viewModel.chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTranslationSettings = true
                } label: {
                    Image(systemName: viewModel.effectiveSettings.autoTranslateEnabled
                          ? "globe.badge.chevron.backward"
                          : "globe")
                }
            }
        }
        .sheet(isPresented: $showTranslationSettings) {
            ConversationTranslationSettingsView(
                chat: viewModel.chat,
                chatListViewModel: chatListViewModel
            )
        }
        .task { await viewModel.loadMessages() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            settings: viewModel.effectiveSettings
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Message bubble

private struct MessageBubbleView: View {
    let message: Message
    let settings: TranslationSettings

    private var displayText: String { message.displayText(settings: settings) }
    private var showOriginal: Bool {
        settings.autoTranslateEnabled && settings.showOriginalText && message.translatedText != nil
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                if !message.isOutgoing {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayText)
                        .padding(10)
                        .background(
                            message.isOutgoing ? Color.accentColor : Color(.systemGray5),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .foregroundStyle(message.isOutgoing ? .white : .primary)

                    if showOriginal, let original = message.translatedText.map({ _ in message.originalText }) {
                        Text(original)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    }
                }

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !message.isOutgoing { Spacer(minLength: 60) }
        }
    }
}
