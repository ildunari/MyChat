// Views/ChatView.swift
import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]
    @Environment(\.tokens) private var T
    @EnvironmentObject private var chatBridge: ChatComposerBridge
    @Environment(SettingsStore.self) private var store

    let chat: Chat
    var onNewChat: (() -> Void)? = nil

    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSuggestions = true
    @State private var showPhotoPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [(data: Data, mime: String)] = []
    @State private var streamingText: String? = nil
    @State private var editingMessage: Message? = nil
    @State private var currentSendTask: Task<Void, Never>? = nil
    @State private var expandedText: String? = nil
    private let expandEvent = Notification.Name("ExpandResponse")
    @State private var reasoningSnippet: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if useWebCanvasFlag {
                ZStack {
                    WebCanvasContainer(chat: chat,
                                       messages: sortedMessages,
                                       streamingText: streamingText,
                                       isSending: isSending)
                    if showSuggestions && sortedMessages.isEmpty {
                        StarterCardGrid(suggestions: defaultSuggestions) { pick in
                            chatBridge.text = composePrompt(from: pick)
                            withAnimation { showSuggestions = false }
                        }
                        .transition(.opacity)
                    }
                }
            } else {
                ZStack {
                    MessageListView(messages: sortedMessages,
                                     streamingText: streamingText,
                                     isSending: isSending,
                                     aiDisplayName: providerDisplayName,
                                     aiModel: currentModel,
                                     onRetry: { msg in Task { await retryResponse(msg) } },
                                     onCopy: { copyResponse($0) },
                                     onEdit: { editMessage($0) },
                                     onReact: { msg, reaction in setReaction(msg, reaction) },
                                     onDelete: { msg in deleteMessage(msg) })
                    if showSuggestions && sortedMessages.isEmpty {
                        StarterCardGrid(suggestions: defaultSuggestions) { pick in
                            chatBridge.text = composePrompt(from: pick)
                            withAnimation { showSuggestions = false }
                        }
                        .transition(.opacity)
                    }
                }
            }
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        // Composer lives in RootView via ChatComposerBridge
        .background(T.bg.ignoresSafeArea())
        .tint(T.accent)
        .sheet(isPresented: $showModelEditor) {
            let providerID = settingsQuery.first?.defaultProvider ?? "openai"
            let modelID = settingsQuery.first?.defaultModel ?? ""
            ModelSettingsView(providerID: providerID, modelID: modelID)
        }
        .sheet(isPresented: $showFullModelPicker) { FullModelPickerSheet() }
        .sheet(isPresented: $showChatSettings) { ChatSettingsSheet() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItems, maxSelectionCount: 4, matching: .images)
        .onChange(of: pickerItems) { _, newItems in
            Task {
                var accum: [(Data, String)] = []
                for item in newItems {
                    if let pair = try? await loadImageData(from: item) {
                        accum.append((pair.data, pair.mime))
                    }
                }
                attachments = accum.map { (data: $0.0, mime: $0.1) }
            }
        }
        .toolbar { toolbarContent }
        // Apply glass material to navigation bar to match liquid glass design
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: expandEvent)) { note in
            if let t = note.userInfo?["text"] as? String { expandedText = t }
        }
        .sheet(isPresented: Binding(get: { expandedText != nil }, set: { v in if !v { expandedText = nil } })) {
            if let t = expandedText {
                NavigationStack { ScrollView { AIResponseView(content: t).padding() }.navigationTitle("Response").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { expandedText = nil } } } }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [shareText])
        }
        // Subtle thinking overlay just under the model name (navigation title area)
        .safeAreaInset(edge: .top, spacing: 0) {
            if isSending, store.showThinkingOverlay {
                ThinkingOverlay(snippet: reasoningSnippet)
                    .padding(.top, 6)
            }
        }
        // Native bottom composer anchored above the system tab bar
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InputBar(text: $chatBridge.text,
                     onSend: { chatBridge.onSend?() },
                     isStreaming: chatBridge.isStreaming,
                     onStop: { chatBridge.onStop?() },
                     onMic: { chatBridge.onMic?() },
                     onLive: { chatBridge.onLive?() },
                     onPlus: { chatBridge.onPlus?() })
            .padding(.horizontal)
            .background(
                // slight material to sit well with glass/tab bar
                Rectangle().fill(T.surface).overlay(Rectangle().fill(T.borderSoft).frame(height: 0.5), alignment: .top)
            )
        }
        .onAppear {
            if isDefaultTitle, let first = sortedMessages.first {
                updateChatTitle(from: first.content)
            }
            showSuggestions = chat.messages.isEmpty
            // Bridge composer actions to RootView overlay
            chatBridge.onSend = { self.currentSendTask = Task { await self.send() } }
            chatBridge.onStop = { self.stopStreaming() }
            chatBridge.onPlus = { self.showPhotoPicker = true }
            chatBridge.isStreaming = (self.streamingText != nil)
        }
        .onChange(of: streamingText) { _, v in chatBridge.isStreaming = (v != nil) }
    }

    // MARK: - WebCanvas integration
    private var useWebCanvasFlag: Bool {
        let wantsWeb = settingsQuery.first?.useWebCanvas ?? true
        return wantsWeb && hasWebCanvasAssets
    }

    private var hasWebCanvasAssets: Bool {
        let b = Bundle.main
        if b.url(forResource: "index", withExtension: "html", subdirectory: "WebCanvas/dist") != nil { return true }
        if b.url(forResource: "index", withExtension: "html", subdirectory: "ChatApp/WebCanvas/dist") != nil { return true }
        return false
    }

    private var currentThemeForCanvas: CanvasTheme {
        // Simple mapping: defer to system for now
        if let pref = settingsQuery.first?.interfaceTheme, pref == "dark" { return .dark }
        if let pref = settingsQuery.first?.interfaceTheme, pref == "light" { return .light }
        // Fall back to light; SwiftUI color scheme not available here without @Environment
        return .light
    }

    private struct WebCanvasContainer: View {
        let chat: Chat
        let messages: [Message]
        let streamingText: String?
        let isSending: Bool
        @StateObject private var controller = ChatCanvasController()
        @Environment(\.colorScheme) private var colorScheme
        @State private var didStartStream = false
        var body: some View {
            ChatCanvasView(controller: controller, theme: (colorScheme == .dark ? .dark : .light))
                .onAppear { loadAll() }
                .onChange(of: messages.count) { _, _ in loadAll() }
                .onChange(of: streamingText) { _, newVal in
                    guard let partial = newVal else { return }
                    // Start stream lazily only once
                    if !didStartStream {
                        controller.startStream(id: "current")
                        didStartStream = true
                    }
                    controller.appendDelta(id: "current", delta: partial)
                    controller.scrollToBottom()
                }
                .onChange(of: isSending) { _, sending in
                    if sending == false {
                        controller.endStream(id: "current")
                        controller.scrollToBottom()
                        didStartStream = false
                    }
                }
        }
        private func loadAll() {
            let items: [CanvasMessage] = messages.map { m in
                CanvasMessage(id: m.id.uuidString, role: m.role, content: m.content, createdAt: m.createdAt.timeIntervalSince1970)
            }
            controller.loadTranscript(items)
            controller.scrollToBottom()
        }
    }

    // Split out heavy view builder to speed up type checking
    private struct MessageListView: View {
        let messages: [Message]
        let streamingText: String?
        let isSending: Bool
        var aiDisplayName: String
        var aiModel: String
        var onRetry: (Message) -> Void
        var onCopy: (Message) -> Void
        var onEdit: (Message) -> Void
        var onReact: (Message, String?) -> Void
        var onDelete: (Message) -> Void
        @State private var showJumpToBottom: Bool = false
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let prevRole = index > 0 ? messages[index-1].role : nil
                            let showHeader = (prevRole != message.role)
                            if message.role == "assistant" {
                                MessageRow(message: message,
                                           aiDisplayName: aiDisplayName,
                                           aiModel: aiModel,
                                           showHeader: showHeader,
                                           onRetry: { onRetry(message) },
                                           onCopy: { onCopy(message) },
                                           onReact: { onReact(message, $0) },
                                           onDelete: { onDelete(message) })
                                    .id(message.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                    .onAppear { if index == messages.count - 1 { showJumpToBottom = false } }
                                    .onDisappear { if index == messages.count - 1 { showJumpToBottom = true } }
                            } else {
                                MessageRow(message: message,
                                           showHeader: showHeader,
                                           onEdit: { onEdit(message) },
                                           onReact: { onReact(message, $0) },
                                           onDelete: { onDelete(message) })
                                    .id(message.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                    .onAppear { if index == messages.count - 1 { showJumpToBottom = false } }
                                    .onDisappear { if index == messages.count - 1 { showJumpToBottom = true } }
                            }
                        }
                        if let partial = streamingText, !partial.isEmpty {
                            StreamingRow(partial: partial, aiDisplayName: aiDisplayName, aiModel: aiModel)
                                .id("streaming")
                                .onAppear { showJumpToBottom = false }
                                .onDisappear { showJumpToBottom = true }
                        } else if isSending {
                            TypingIndicator()
                                .padding(.horizontal)
                                .id("typing")
                                .onAppear { showJumpToBottom = false }
                                .onDisappear { showJumpToBottom = true }
                        }
                    }
                }
                .padding(.bottom, 140) // leave room for composer + dock bar
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showJumpToBottom {
                        Button(action: {
                            if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                        }) {
                            HStack(spacing: 6) { AppIcon.chevronDown(12); Text("Bottom").font(.caption) }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private struct MessageRow: View {
        let message: Message
        // For assistant header
        var aiDisplayName: String = "AI"
        var aiModel: String = ""
        var showHeader: Bool = true
        @Environment(\.tokens) private var T
        var onRetry: (() -> Void)? = nil
        var onCopy: (() -> Void)? = nil
        var onEdit: (() -> Void)? = nil
        var onReact: ((String?) -> Void)? = nil
        var onDelete: (() -> Void)? = nil
        var body: some View {
            Group {
                if message.role == "assistant" {
                    // Full-bleed AI response (no bubble), with header
                    VStack(alignment: .leading, spacing: 6) {
                        if showHeader {
                            HStack(spacing: 6) {
                                AppIcon.starsHeader(14)
                                    .foregroundStyle(T.textSecondary)
                                Text("\(aiDisplayName) \(aiModel)")
                                    .font(.footnote)
                                    .foregroundStyle(T.textSecondary)
                            }
                        }
                        AIResponseView(content: message.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 12) {
                            Button("Retry") { onRetry?() }
                            Button("Copy") { onCopy?() }
                            Button("Expand") { NotificationCenter.default.post(name: Notification.Name("ExpandResponse"), object: nil, userInfo: ["text": message.content]) }
                            // Reactions
                            Spacer(minLength: 8)
                            Button(action: { onReact?(message.reaction == "up" ? nil : "up") }) { Image(systemName: message.reaction == "up" ? "hand.thumbsup.fill" : "hand.thumbsup") }
                            Button(action: { onReact?(message.reaction == "down" ? nil : "down") }) { Image(systemName: message.reaction == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown") }
                        }
                        .font(.footnote)
                        .padding(.top, 4)
                        Text(relativeTime(message.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .contextMenu {
                        Button("Copy") { onCopy?() }
                        Button("Retry") { onRetry?() }
                        Button("Expand") { NotificationCenter.default.post(name: Notification.Name("ExpandResponse"), object: nil, userInfo: ["text": message.content]) }
                        Divider()
                        Button(message.reaction == "up" ? "Remove Like" : "Like") { onReact?(message.reaction == "up" ? nil : "up") }
                        Button(message.reaction == "down" ? "Remove Dislike" : "Dislike") { onReact?(message.reaction == "down" ? nil : "down") }
                    }
                } else {
                    // User message aligned to the right with tighter corner radius
                    VStack(alignment: .trailing, spacing: 4) {
                        if showHeader {
                            Text("You")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Button("Edit") { onEdit?() }
                            .font(.footnote)
                        Text(message.content)
                            .font(.system(.body, design: .rounded)).fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(T.bubbleUser)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(T.borderSoft, lineWidth: 1)
                            )
                            .frame(maxWidth: 320, alignment: .trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(relativeTime(message.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .contextMenu {
                        Button("Copy") { onCopy?() }
                        Button("Edit") { onEdit?() }
                        Divider()
                        Button("Delete", role: .destructive) { onDelete?() }
                    }
                }
            }
        }
    }

    private struct StreamingRow: View {
        let partial: String
        var aiDisplayName: String = "AI"
        var aiModel: String = ""
        @Environment(\.tokens) private var T
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    AppIcon.starsHeader(14)
                        .foregroundStyle(T.textSecondary)
                    Text("\(aiDisplayName) \(aiModel)")
                        .font(.footnote)
                        .foregroundStyle(T.textSecondary)
                }
                AIResponseView(content: partial)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
        }
    }

    private struct TypingIndicator: View {
        @State private var phase: Int = 0
        var body: some View {
            HStack(spacing: 8) {
                Text("Assistant is typing")
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).opacity(phase == 0 ? 1 : 0.3)
                    Circle().frame(width: 6, height: 6).opacity(phase == 1 ? 1 : 0.3)
                    Circle().frame(width: 6, height: 6).opacity(phase == 2 ? 1 : 0.3)
                }
                .foregroundStyle(.secondary)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    phase = 2
                }
            }
        }
    }

    // (Helper moved to file scope below.)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Center model display with quick menu
        ToolbarItem(placement: .principal) {
            Menu {
                // Quick models (up to 3)
                Section("Quick Models") {
                    ForEach(quickModels(), id: \.self) { m in
                        Button(action: { setDefaultModel(m) }) {
                            HStack { Text(m); if m == (settingsQuery.first?.defaultModel ?? "") { AppIcon.checkCircle(true, size: 14) } }
                        }
                    }
                }
                Button("Other models…") { showFullModelPicker = true }
                Divider()
                Button("Chat Settings…") { showChatSettings = true }
                Button("Export / Share Transcript") { shareText = composeTranscript(); showShare = true }
            } label: {
                HStack(spacing: 4) {
                    Text(currentModelDisplay()).font(.headline)
                    AppIcon.chevronDown(10).rotationEffect(.degrees(-90))
                }
                .contentShape(Rectangle())
            }
        }
        // Leading button: toggle chat history drawer
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { AppNavEvent.toggleHistoryDrawer() }) {
                Image(systemName: "sidebar.leading").font(.system(size: 16, weight: .semibold))
            }
            .accessibilityLabel("Toggle Chat History")
        }
        // Top-right new chat button
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { onNewChat?() }) { AppIcon.plus(18) }
                .accessibilityLabel("New Chat")
        }
    }

    private func currentModelDisplay() -> String {
        let s = settingsQuery.first
        return s?.defaultModel.isEmpty == false ? (s?.defaultModel ?? "Model") : "Model"
    }

    private func availableModelsForCurrentProvider() -> [String] {
        let s = settingsQuery.first
        switch s?.defaultProvider ?? "openai" {
        case "openai": return s?.openAIEnabledModels ?? []
        case "anthropic": return s?.anthropicEnabledModels ?? []
        case "google": return s?.googleEnabledModels ?? []
        case "xai": return s?.xaiEnabledModels ?? []
        default: return []
        }
    }

    private func setDefaultModel(_ m: String) {
        guard let s = settingsQuery.first else { return }
        s.defaultModel = m
        try? modelContext.save()
    }

    private func quickModels() -> [String] {
        // Default model + two more from enabled list for current provider
        let s = settingsQuery.first
        let current = s?.defaultModel ?? ""
        var pool = availableModelsForCurrentProvider()
        if let i = pool.firstIndex(of: current) { pool.remove(at: i) }
        var out = [String]()
        if !current.isEmpty { out.append(current) }
        out.append(contentsOf: pool.prefix(2))
        // Deduplicate and cap at 3
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }

    private var defaultSuggestions: [SuggestionChipItem] {
        [
            .init(title: "Identify the best", subtitle: "high-performance pre-workouts"),
            .init(title: "Explore the latest", subtitle: "AI-powered research"),
            .init(title: "Plan a trip", subtitle: "2-day foodie itinerary"),
            .init(title: "Summarize a PDF", subtitle: "key points + action items"),
            .init(title: "Improve writing", subtitle: "tone and clarity suggestions"),
            .init(title: "Code review", subtitle: "spot bugs and edge cases")
        ]
    }

    private var contentBottomPadding: CGFloat {
        // Ensure chat content never collides with inset UI.
        let input: CGFloat = 44 + 24 // field height + margins
        return input
    }

    private func composePrompt(from item: SuggestionChipItem) -> String {
        "\(item.title): \(item.subtitle)"
    }

    // Height of the custom DockTabBar at the app root (approx 72). Keep a little buffer.
    private var dockBarHeight: CGFloat { 76 }

    // MARK: - Sheets
    @MainActor
    private struct FullModelPickerSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @Query private var settingsQuery: [AppSettings]
        var body: some View {
            NavigationStack {
                List {
                    Section("OpenAI") { modelList(provider: "openai") }
                    Section("Anthropic") { modelList(provider: "anthropic") }
                    Section("Google") { modelList(provider: "google") }
                    Section("XAI") { modelList(provider: "xai") }
                }
                .navigationTitle("All Models")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            }
        }
        @ViewBuilder private func modelList(provider: String) -> some View {
            let s = settingsQuery.first
            let models: [String] = {
                switch provider {
                case "openai": return s?.openAIEnabledModels ?? []
                case "anthropic": return s?.anthropicEnabledModels ?? []
                case "google": return s?.googleEnabledModels ?? []
                case "xai": return s?.xaiEnabledModels ?? []
                default: return []
                }
            }()
            ForEach(models, id: \.self) { m in
                Button(action: {
                    if let s = settingsQuery.first {
                        s.defaultProvider = provider
                        s.defaultModel = m
                        try? modelContext.save()
                    }
                    dismiss()
                }) {
                    HStack { Text(m); if m == (settingsQuery.first?.defaultModel ?? "") { AppIcon.checkCircle(true, size: 14) } }
                }
            }
        }
    }

    @MainActor
    private struct ChatSettingsSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @Query private var settingsQuery: [AppSettings]
        @State private var systemPrompt: String = ""
        @State private var temperature: Double = 1.0
        @State private var maxTokens: Double = 1024
        @State private var historyLimit: Int = -1 // -1 = All
        var body: some View {
            let defaults = settingsQuery.first
            NavigationStack {
                Form {
                    Section("System Instruction") {
                        TextEditor(text: Binding(get: { systemPrompt }, set: { systemPrompt = $0 }))
                            .frame(minHeight: 120)
                    }
                    Section("Sampling") {
                        HStack { Text("Temperature"); Spacer(); Text(String(format: "%.2f", temperature)).foregroundStyle(.secondary) }
                        Slider(value: $temperature, in: 0...2, step: 0.05)
                        Stepper("Max output tokens: \(Int(maxTokens))", value: $maxTokens, in: 128...32768, step: 128)
                    }
                    Section("History") {
                        Picker("Messages included", selection: Binding(get: { historyLimit }, set: { historyLimit = $0 })) {
                            Text("All previous").tag(-1)
                            Text("Last 5").tag(5)
                            Text("Last 10").tag(10)
                            Text("Last 20").tag(20)
                        }.pickerStyle(.menu)
                    }
                }
                .onAppear {
                    systemPrompt = defaults?.defaultSystemPrompt ?? systemPrompt
                    temperature = defaults?.defaultTemperature ?? temperature
                    maxTokens = Double(defaults?.defaultMaxTokens ?? Int(maxTokens))
                    historyLimit = defaults?.defaultHistoryLimit ?? -1
                }
                .navigationTitle("Chat Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let s = settingsQuery.first {
                                s.defaultSystemPrompt = systemPrompt
                                s.defaultTemperature = temperature
                                s.defaultMaxTokens = Int(maxTokens)
                                s.defaultHistoryLimit = historyLimit
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var sortedMessages: [Message] {
        chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var isDefaultTitle: Bool {
        chat.title.isEmpty || chat.title == "New Chat"
    }

    @MainActor
    private func send() async {
        guard !isSending else { return }
        let userText = chatBridge.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        chatBridge.text = ""
        errorMessage = nil
        withAnimation { showSuggestions = false }

        // Insert or update user message
        if let editing = editingMessage {
            editing.content = userText
            editing.createdAt = Date()
            let msgs = chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
            if let idx = msgs.firstIndex(where: { $0.id == editing.id }) {
                for m in msgs.suffix(from: idx + 1) { modelContext.delete(m) }
            }
            try? modelContext.save()
        } else {
            let userMsg = Message(role: "user", content: userText, chat: chat)
            modelContext.insert(userMsg)
            try? modelContext.save()
        }

        isSending = true
        defer { isSending = false; currentSendTask = nil; editingMessage = nil }

        do {
            // Resolve provider from settings
            let settings = settingsQuery.first ?? AppSettings()
            let providerID = settings.defaultProvider
            let model = effectiveModel(for: providerID)

            let provider = try makeProvider(id: providerID)
            var aiMessages: [AIMessage] = []
            // Master system prompt first, then user-provided system prompt
            aiMessages.append(AIMessage(role: .system, content: MASTER_SYSTEM_PROMPT))
            let sys = settings.defaultSystemPrompt
            if sys.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                aiMessages.append(AIMessage(role: .system, content: sys))
            }

            // Use previous messages, optionally limiting to the last N per AppSettings
            var previous = chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
            if editingMessage == nil, let last = previous.last, last.content == userText { previous.removeLast() }
            let historyLimit = settings.defaultHistoryLimit
            if historyLimit > 0 && previous.count > historyLimit {
                previous = Array(previous.suffix(historyLimit))
            }
            aiMessages.append(contentsOf: previous.map { m in
                AIMessage(role: m.role == "user" ? .user : .assistant, content: m.content)
            })

            // Compose the current user message with optional image parts (preserve MIME) if not editing
            if editingMessage == nil {
                let imageParts = attachments.map { AIMessage.Part.imageData($0.data, mime: $0.mime) }
                aiMessages.append(AIMessage(role: .user, parts: [.text(userText)] + imageParts))
            }

            // Apply per-model overrides from ModelCapabilitiesStore
            var caps = ModelCapabilitiesStore.get(provider: providerID, model: model) // effective (user over default)
            // If per-model caching isn't set, honor global Settings toggle as a soft default
            if caps?.enablePromptCaching == nil, store.promptCachingEnabled {
                var updated = caps ?? .fallback(id: model)
                updated.enablePromptCaching = true
                ModelCapabilitiesStore.putUser(provider: providerID, model: model, info: updated)
                caps = updated
            }
            let tempEff = caps?.preferredTemperature ?? settings.defaultTemperature
            let topPEff = caps?.preferredTopP
            let topKEff = caps?.preferredTopK
            let maxOutEff = min(settings.defaultMaxTokens, caps?.outputTokenLimit ?? settings.defaultMaxTokens)
            let userMaxOut = caps?.preferredMaxOutputTokens
            let finalMaxOut = userMaxOut.map { min($0, maxOutEff) } ?? maxOutEff
            let reasoningEff = caps?.preferredReasoningEffort
            let verbosityEff = caps?.preferredVerbosity

            let reply: String
            if let streaming2 = provider as? AIStreamingProviderV2 {
                streamingText = ""
                reasoningSnippet = ""
                reply = try await streaming2.streamChat(
                    messages: aiMessages,
                    model: model,
                    temperature: tempEff,
                    topP: topPEff,
                    topK: topKEff,
                    maxOutputTokens: finalMaxOut,
                    reasoningEffort: reasoningEff,
                    verbosity: verbosityEff
                ) { delta in
                    Task { @MainActor in
                        self.streamingText = (self.streamingText ?? "") + delta
                    }
                } onReasoningDelta: { rdelta in
                    guard store.showReasoningSnippets else { return }
                    Task { @MainActor in
                        let combined = (self.reasoningSnippet + rdelta).replacingOccurrences(of: "\n", with: " ")
                        self.reasoningSnippet = String(combined.suffix(90))
                    }
                }
            } else if let streaming = provider as? AIStreamingProvider {
                streamingText = ""
                reply = try await streaming.streamChat(
                    messages: aiMessages,
                    model: model,
                    temperature: tempEff,
                    topP: topPEff,
                    topK: topKEff,
                    maxOutputTokens: finalMaxOut,
                    reasoningEffort: reasoningEff,
                    verbosity: verbosityEff
                ) { delta in
                    Task { @MainActor in
                        self.streamingText = (self.streamingText ?? "") + delta
                    }
                }
            } else if let adv = provider as? AIProviderAdvanced {
                reply = try await adv.sendChat(
                    messages: aiMessages,
                    model: model,
                    temperature: tempEff,
                    topP: topPEff,
                    topK: topKEff,
                    maxOutputTokens: finalMaxOut,
                    reasoningEffort: reasoningEff,
                    verbosity: verbosityEff
                )
            } else {
                reply = try await provider.sendChat(messages: aiMessages, model: model)
            }

            // Add assistant message
            streamingText = nil
            reasoningSnippet = ""
            let aiMsg = Message(role: "assistant", content: reply, chat: chat)
            modelContext.insert(aiMsg)

            // Update title if still default
            if isDefaultTitle {
                updateChatTitle(from: userText)
            }

            try? modelContext.save()
            attachments.removeAll()
        } catch is CancellationError {
            // User stopped streaming. Finalize partial text if any, without surfacing an error.
            if let partial = streamingText, !partial.isEmpty {
                streamingText = nil
                let aiMsg = Message(role: "assistant", content: partial, chat: chat)
                modelContext.insert(aiMsg)
                try? modelContext.save()
            } else { streamingText = nil }
            reasoningSnippet = ""
            errorMessage = nil
        } catch {
            // Any non-cancellation error: clear streaming state and surface message
            streamingText = nil
            reasoningSnippet = ""
            errorMessage = (error as NSError).localizedDescription
        }
    }

    // MARK: - Stop streaming
    @MainActor
    private func stopStreaming() {
        // Cancel the in-flight send task, if any.
        currentSendTask?.cancel()
        // If there's partial streamed content, finalize it as a message for continuity.
        if let partial = streamingText, !partial.isEmpty {
            streamingText = nil
            let aiMsg = Message(role: "assistant", content: partial, chat: chat)
            modelContext.insert(aiMsg)
            try? modelContext.save()
        } else {
            streamingText = nil
        }
        isSending = false
        attachments.removeAll()
    }

    // Subtle "thinking" overlay with glass capsule and animated dots. Shows a short, rolling snippet.
    private struct ThinkingOverlay: View {
        let snippet: String
        @Environment(\.tokens) private var T
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var phase: Double = 0
        var body: some View {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).opacity(opacity(0))
                    Circle().frame(width: 6, height: 6).opacity(opacity(1))
                    Circle().frame(width: 6, height: 6).opacity(opacity(2))
                }
                .foregroundStyle(T.accent)
                Text(snippet.isEmpty ? "Thinking…" : snippet)
                    .font(.footnote)
                    .foregroundStyle(T.text)
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(T.borderSoft, lineWidth: 0.7))
            .shadow(color: T.shadow.opacity(0.12), radius: 6, y: 2)
            .onAppear {
                if reduceMotion {
                    phase = 1
                } else {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever()) { phase = 1 }
                }
            }
        }
        private func opacity(_ i: Int) -> Double { max(0.25, 1 - abs(sin(phase * .pi + Double(i) * 0.8))) }
    }

    // MARK: - Provider header helpers
    private var providerDisplayName: String {
        let p = settingsQuery.first?.defaultProvider ?? "openai"
        return ProviderID(rawValue: p)?.displayName ?? "AI"
    }
    private var currentModel: String {
        settingsQuery.first?.defaultModel ?? ""
    }

    private func effectiveModel(for providerID: String) -> String {
        let configured = settingsQuery.first?.defaultModel ?? ""
        let allowed = availableModelsForCurrentProvider()
        if allowed.contains(configured), !configured.isEmpty { return configured }
        var fallback = configured
        switch providerID {
        case "openai": fallback = "gpt-4o-mini"
        case "anthropic": fallback = "claude-3-5-sonnet-20240620"
        case "google": fallback = "gemini-1.5-pro"
        case "xai": fallback = "grok-2-mini"
        default: break
        }
        if fallback.isEmpty { fallback = allowed.first ?? configured }
        if let s = settingsQuery.first { s.defaultModel = fallback; try? modelContext.save() }
        return fallback
    }

    @State private var showModelEditor: Bool = false
    @State private var showFullModelPicker: Bool = false
    @State private var showChatSettings: Bool = false
    @State private var showShare: Bool = false
    @State private var shareText: String = ""

    private func updateChatTitle(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        chat.title = String(trimmed.prefix(40))
        try? modelContext.save()
    }

    private func makeProvider(id: String) throws -> AIProvider {
        switch id {
        case "openai":
            let key = (try? KeychainService.read(key: "openai_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set. Open Settings to add your key."])
            }
            return OpenAIProvider(apiKey: key)
        case "anthropic":
            let key = (try? KeychainService.read(key: "anthropic_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key not set. Open Settings to add your key."])
            }
            return AnthropicProvider(apiKey: key)
        case "google":
            let key = (try? KeychainService.read(key: "google_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google API key not set. Open Settings to add your key."])
            }
            return GoogleProvider(apiKey: key)
        case "xai":
            let key = (try? KeychainService.read(key: "xai_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "XAI API key not set. Open Settings to add your key."])
            }
            return XAIProvider(apiKey: key)
        default:
            throw NSError(domain: "Provider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider: \(id)"])
        }
    }

    // Compose Markdown transcript for export/share
    private func composeTranscript() -> String {
        var out = "# \(chat.title.isEmpty ? "Chat" : chat.title)\n\n"
        for m in sortedMessages {
            if m.role == "user" {
                out += "**You** (\(relativeTime(m.createdAt))):\n\n"
                out += m.content + "\n\n"
            } else {
                out += "**Assistant** (\(relativeTime(m.createdAt))):\n\n"
                out += m.content + "\n\n"
            }
        }
        return out
    }

    // MARK: - Message actions
    private func retryResponse(_ message: Message) async {
        guard let idx = sortedMessages.firstIndex(where: { $0.id == message.id }) else { return }
        modelContext.delete(message)
        try? modelContext.save()
        if let prevUser = sortedMessages[..<idx].last(where: { $0.role == "user" }) {
            editingMessage = prevUser
            chatBridge.text = prevUser.content
            await send()
        }
    }

    private func copyResponse(_ message: Message) {
        UIPasteboard.general.string = message.content
    }

    @MainActor
    private func setReaction(_ message: Message, _ reaction: String?) {
        message.reaction = reaction
        try? modelContext.save()
    }

    @MainActor
    private func deleteMessage(_ message: Message) {
        modelContext.delete(message)
        try? modelContext.save()
    }

    private func editMessage(_ message: Message) {
        editingMessage = message
        chatBridge.text = message.content
    }
}

// (Expanded response is handled via Notification + sheet above.)

// Share sheet wrapper
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    if let container = try? ModelContainer(
        for: Chat.self, Message.self, AppSettings.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        let context = ModelContext(container)
        let chat = Chat(title: "Preview Chat")
        context.insert(chat)
        context.insert(Message(role: "user", content: "Hello!", chat: chat))
        return AnyView(
            NavigationStack {
                ChatView(chat: chat)
            }
            .modelContainer(container)
            .environmentObject(ChatComposerBridge())
        )
    } else {
        return AnyView(Text("Preview unavailable"))
    }
}

// MARK: - PhotosPicker helpers
private func loadImageData(from item: PhotosPickerItem) async throws -> (data: Data, mime: String) {
    if let type = item.supportedContentTypes.first {
        if type.conforms(to: .jpeg) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            return (data, "image/jpeg")
        } else if type.conforms(to: .png) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            return (data, "image/png")
        } else if type.conforms(to: .heic) || type.conforms(to: .heif) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            return (data, "image/heic")
        }
    }
    // Fallback: try as raw Data and mark as JPEG
    if let data = try await item.loadTransferable(type: Data.self) { return (data, "image/jpeg") }
    throw NSError(domain: "Photos", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not load image data"]) 
}

// File-scope helper for relative times
private func relativeTime(_ date: Date) -> String {
    let secs = max(1, Int(Date().timeIntervalSince(date)))
    if secs < 60 { return "just now" }
    if secs < 3600 { return "\(secs/60)m ago" }
    let hrs = secs / 3600
    if hrs < 48 { return "\(hrs)h ago" }
    let days = hrs / 24
    if days < 14 { return "\(days)d ago" }
    return "\(days/7)w ago"
}
