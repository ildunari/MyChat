// Views/ChatView.swift
import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]
    @Environment(\.tokens) private var T

    let chat: Chat

    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSuggestions = true
    @State private var showPhotoPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [(data: Data, mime: String)] = []
    @State private var streamingText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if useWebCanvasFlag {
                WebCanvasContainer(chat: chat,
                                   messages: sortedMessages,
                                   streamingText: streamingText,
                                   isSending: isSending)
            } else {
                MessageListView(messages: sortedMessages,
                                 streamingText: streamingText,
                                 isSending: isSending,
                                 aiDisplayName: providerDisplayName,
                                 aiModel: currentModel)
            }
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { // pins bottom controls and prevents overlap
            VStack(spacing: 0) {
                if showSuggestions {
                    SuggestionChips(suggestions: defaultSuggestions)
                        .padding(.bottom, 16) // Add padding between suggestions and input bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                InputBar(text: $inputText, onSend: { Task { await send() } }, onMic: nil, onLive: nil, onPlus: { showPhotoPicker = true })
                    .disabled(isSending)
                    .padding(.top, 6) // Reduced padding above input bar
            }
            .background(
                VStack(spacing: 0) {
                    Divider().overlay(T.borderSoft).frame(height: 1)
                    Rectangle().fill(T.surface).ignoresSafeArea()
                }
            )
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $showModelEditor) {
            let providerID = settingsQuery.first?.defaultProvider ?? "openai"
            let modelID = settingsQuery.first?.defaultModel ?? ""
            ModelSettingsView(providerID: providerID, modelID: modelID)
        }
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isDefaultTitle, let first = sortedMessages.first {
                updateChatTitle(from: first.content)
            }
            showSuggestions = chat.messages.isEmpty
        }
    }

    // MARK: - WebCanvas integration
    private var useWebCanvasFlag: Bool {
        settingsQuery.first?.useWebCanvas ?? true
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
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            if message.role == "assistant" {
                                MessageRow(message: message,
                                           aiDisplayName: aiDisplayName,
                                           aiModel: aiModel)
                            } else {
                                MessageRow(message: message)
                            }
                        }
                if let partial = streamingText {
                    StreamingRow(partial: partial)
                } else if isSending {
                            HStack { ProgressView(); Text("Thinking…").foregroundStyle(.secondary) }
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 72)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
        @Environment(\.tokens) private var T
        var body: some View {
            Group {
                if message.role == "assistant" {
                    // Full-bleed AI response (no bubble), with header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            AppIcon.starsHeader(14)
                                .foregroundStyle(T.textSecondary)
                            Text("\(aiDisplayName) \(aiModel)")
                                .font(.footnote)
                                .foregroundStyle(T.textSecondary)
                        }
                        AIResponseView(content: message.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                } else {
                    // User message with a subtle bubble
                    HStack(alignment: .top, spacing: 8) {
                        Text("You")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                        Text(message.content)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(T.bubbleUser)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(T.borderSoft, lineWidth: 1)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Default back button preserved; no custom leading item
        ToolbarItem(placement: .principal) {
            Menu {
                // Model picker populated from AppSettings enabled lists
                ForEach(availableModelsForCurrentProvider(), id: \.self) { m in
                    Button(action: { setDefaultModel(m) }) {
                        HStack {
                            Text(m)
                            if m == (settingsQuery.first?.defaultModel ?? "") {
                                AppIcon.checkCircle(true, size: 14)
                            }
                        }
                    }
                }
                Divider()
                Button {
                    showModelEditor = true
                } label: { HStack(spacing: 6) { AppIcon.info(14); Text("Model Info") } }
            } label: {
                HStack(spacing: 4) {
                    Text(currentModelDisplay()).font(.headline)
                    AppIcon.chevronDown(10).rotationEffect(.degrees(-90))
                }
                .contentShape(Rectangle())
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { } label: { AppIcon.info(18) }
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
        let chips: CGFloat = showSuggestions ? (60 + 16) : 0
        return input + chips
    }

    private var sortedMessages: [Message] {
        chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var isDefaultTitle: Bool {
        chat.title.isEmpty || chat.title == "New Chat"
    }

    @MainActor
    private func send() async {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        inputText = ""
        errorMessage = nil
        withAnimation { showSuggestions = false }

        // Add user message
        let userMsg = Message(role: "user", content: userText, chat: chat)
        modelContext.insert(userMsg)
        try? modelContext.save()

        isSending = true
        defer { isSending = false }

        do {
            // Resolve provider from settings
            let settings = settingsQuery.first ?? AppSettings()
            let providerID = settings.defaultProvider
            let model = settings.defaultModel

            let provider = try makeProvider(id: providerID)
            var aiMessages: [AIMessage] = []
            // Master system prompt first, then user-provided system prompt
            aiMessages.append(AIMessage(role: .system, content: MASTER_SYSTEM_PROMPT))
            let sys = settings.defaultSystemPrompt
            if sys.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                aiMessages.append(AIMessage(role: .system, content: sys))
            }

            // Use all previous messages except the just-inserted user message
            var previous = chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
            if let last = previous.last, last.content == userText { previous.removeLast() }
            aiMessages.append(contentsOf: previous.map { m in
                AIMessage(role: m.role == "user" ? .user : .assistant, content: m.content)
            })

            // Compose the current user message with optional image parts (preserve MIME)
            let imageParts = attachments.map { AIMessage.Part.imageData($0.data, mime: $0.mime) }
            aiMessages.append(AIMessage(role: .user, parts: [.text(userText)] + imageParts))

            // Apply per-model overrides from ModelCapabilitiesStore
            let caps = ModelCapabilitiesStore.get(provider: providerID, model: model) // effective (user over default)
            let tempEff = caps?.preferredTemperature ?? settings.defaultTemperature
            let topPEff = caps?.preferredTopP
            let topKEff = caps?.preferredTopK
            let maxOutEff = min(settings.defaultMaxTokens, caps?.outputTokenLimit ?? settings.defaultMaxTokens)
            let userMaxOut = caps?.preferredMaxOutputTokens
            let finalMaxOut = userMaxOut.map { min($0, maxOutEff) } ?? maxOutEff
            let reasoningEff = caps?.preferredReasoningEffort
            let verbosityEff = caps?.preferredVerbosity

            let reply: String
            if let streaming = provider as? AIStreamingProvider {
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
            let aiMsg = Message(role: "assistant", content: reply, chat: chat)
            modelContext.insert(aiMsg)

            // Update title if still default
            if isDefaultTitle {
                updateChatTitle(from: userText)
            }

            try? modelContext.save()
            attachments.removeAll()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    // MARK: - Provider header helpers
    private var providerDisplayName: String {
        let p = settingsQuery.first?.defaultProvider ?? "openai"
        return ProviderID(rawValue: p)?.displayName ?? "AI"
    }
    private var currentModel: String {
        settingsQuery.first?.defaultModel ?? ""
    }

    @State private var showModelEditor: Bool = false

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
