import SwiftUI
import BZGramCore

/// 对话详情视图（消息收发 + 翻译 + 编辑 + 长按菜单）
public struct ChatView: View {

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var chatListViewModel: ChatListViewModel
    @State private var showTranslationSettings = false
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: ChatViewModel, chatListViewModel: ChatListViewModel) {
        self.viewModel = viewModel
        self.chatListViewModel = chatListViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("加载消息中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageList
                editingBanner
                replyBanner
                errorBanner
                composer
            }
        }
        .navigationTitle(viewModel.chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.searchQuery,
            isPresented: $viewModel.isSearching,
            prompt: "搜索消息…"
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation { viewModel.isSearching.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    Button {
                        showTranslationSettings = true
                    } label: {
                        Image(systemName: viewModel.effectiveSettings.autoTranslateEnabled
                              ? "globe.badge.chevron.backward"
                              : "globe")
                    }
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

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    let displayMessages = viewModel.isSearching ? viewModel.filteredMessages : viewModel.messages
                    ForEach(displayMessages) { message in
                        MessageBubbleView(
                            message: message,
                            settings: viewModel.effectiveSettings,
                            onEdit: { viewModel.startEditing(message) },
                            onDelete: { Task { await viewModel.deleteMessage(message) } },
                            onReply: { viewModel.setReply(to: message) },
                            onRetry: { Task { await viewModel.retryMessage(message) } }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onAppear {
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 编辑中提示

    @ViewBuilder
    private var editingBanner: some View {
        if let editing = viewModel.editingMessage {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("正在编辑")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(editing.originalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button { viewModel.cancelEditing() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - 回复中提示

    @ViewBuilder
    private var replyBanner: some View {
        if let reply = viewModel.replyToMessage {
            HStack {
                Rectangle()
                    .fill(.accentColor)
                    .frame(width: 3)
                VStack(alignment: .leading) {
                    Text(reply.senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accentColor)
                    Text(reply.originalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button { viewModel.cancelReply() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - 错误提示

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
        }
    }

    // MARK: - 消息输入框

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(viewModel.isEditing ? "编辑消息…" : "发送消息…",
                      text: $viewModel.draftMessage,
                      axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            if viewModel.isEditing {
                Button {
                    Task { await viewModel.submitEdit() }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            } else {
                Button {
                    Task { await viewModel.sendCurrentDraft() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }
                .disabled(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {
    let message: Message
    let settings: TranslationSettings
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onReply: () -> Void
    var onRetry: () -> Void

    private var displayText: String { message.displayText(settings: settings) }
    private var showOriginal: Bool {
        settings.autoTranslateEnabled && settings.showOriginalText && message.translatedText != nil
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 50) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 3) {
                if !message.isOutgoing {
                    Text(message.senderName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.accentColor)
                }

                // 消息内容卡片
                VStack(alignment: .leading, spacing: 4) {
                    // 消息类型图标
                    if message.contentType != .text {
                        HStack(spacing: 4) {
                            Image(systemName: contentTypeIcon)
                                .font(.caption)
                            Text(contentTypeLabel)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    Text(displayText)
                        .font(.body)

                    if showOriginal {
                        Divider()
                        Text(message.originalText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(
                    bubbleBackgroundColor,
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.isOutgoing && message.sendStatus != .failed ? .white : .primary)
                .contextMenu {
                    // 发送失败的消息只显示重试
                    if message.sendStatus == .failed {
                        Button(action: onRetry) {
                            Label("重新发送", systemImage: "arrow.clockwise")
                        }
                    } else {
                        Button { UIPasteboard.general.string = displayText } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        Button(action: onReply) {
                            Label("回复", systemImage: "arrowshape.turn.up.left")
                        }
                        if message.canBeEdited {
                            Button(action: onEdit) {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        if message.canBeDeleted {
                            Button(role: .destructive, action: onDelete) {
                                Label("撤回", systemImage: "trash")
                            }
                        }
                    }
                }

                // 状态行
                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if message.isEdited {
                        Text("已编辑")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    // 发送状态指示器
                    if message.isOutgoing {
                        sendStatusIndicator
                    }
                }
            }

            if !message.isOutgoing { Spacer(minLength: 50) }
        }
    }

    /// 气泡背景色（根据发送状态变化）
    private var bubbleBackgroundColor: Color {
        if message.sendStatus == .failed {
            return Color.red.opacity(0.2)
        } else if message.sendStatus == .sending {
            return Color.accentColor.opacity(0.6)
        } else {
            return message.isOutgoing ? Color.accentColor : Color(.systemGray5)
        }
    }

    /// 发送状态指示器
    @ViewBuilder
    private var sendStatusIndicator: some View {
        switch message.sendStatus {
        case .sending:
            ProgressView()
                .scaleEffect(0.5)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    private var contentTypeIcon: String {
        switch message.contentType {
        case .photo: return "photo"
        case .video: return "play.rectangle"
        case .document: return "doc"
        case .sticker: return "face.smiling"
        case .voice: return "waveform"
        case .animation: return "gift"
        case .location: return "location"
        case .contact: return "person.crop.circle"
        default: return "doc"
        }
    }

    private var contentTypeLabel: String {
        switch message.contentType {
        case .photo: return "图片"
        case .video: return "视频"
        case .document: return "文件"
        case .sticker: return "贴纸"
        case .voice: return "语音"
        case .animation: return "动图"
        case .location: return "位置"
        case .contact: return "联系人"
        default: return ""
        }
    }
}
