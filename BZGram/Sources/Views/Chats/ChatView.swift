import SwiftUI
import BZGramCore

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
                VStack(spacing: 0) {
                    messageList
                    composer
                }
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
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $viewModel.draftMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button("Send") {
                Task { await viewModel.sendCurrentDraft() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.thinMaterial)
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

                    if showOriginal {
                        Text(message.originalText)
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
