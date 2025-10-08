// Views/ChatView.swift
import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Foundation

private let reasoningMessageRole = "assistant_reasoning"

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]
    @Environment(\.tokens) private var T
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dockController: DockController

    let chat: Chat
    var onNewChat: (() -> Void)? = nil

    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSuggestions = true
    @State private var showPhotoPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [(data: Data, mime: String)] = []
    @StateObject private var streamingMarkdown = StreamingMarkdownState()
    @State private var editingMessage: Message? = nil
    @State private var currentSendTask: Task<Void, Never>? = nil
    @State private var activeTurnID: UUID?
    @State private var pendingVersionIndex: Int = 1
    @State private var retryingUserMessage: Message? = nil
    @State private var hasNormalizedExistingMessages = false

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(messages: displayMessages,
                             streamingSnapshot: activeStreamingSnapshot,
                             isSending: isSending,
                             aiDisplayName: effectiveAIDisplayName,
                             aiModel: currentModel,
                             userDisplayName: userDisplayName,
                             showReasoningSnippets: showReasoningSnippetsFlag,
                             bottomInset: dockController.currentHeight + 24,
                             streamingVersionIndex: activeStreamingSnapshot != nil ? pendingVersionIndex : nil,
                             versionMeta: assistantVersionMeta,
                             onRetry: { msg in
                                 currentSendTask = Task { await retryResponse(msg) }
                             },
                             onCopy: { copyResponse($0) },
                             onEdit: { editMessage($0) },
                             onScroll: handleScrollChange)
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        // Pins bottom controls and prevents overlap
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                InputBar(text: $inputText,
                         onSend: { currentSendTask = Task { await send() } },
                         isStreaming: activeStreamingSnapshot != nil,
                         onStop: { stopStreaming() },
                         onMic: nil,
                         onLive: nil,
                         onPlus: { showPhotoPicker = true })
                    .padding(.top, 2)
                    .padding(.bottom, dockController.currentHeight + 12)
            }
            .safeAreaPadding(.bottom, 0)
        }
        // Floating Liquid Glass navigation bar + thinking indicator
        .safeAreaInset(edge: .top, spacing: 12) {
            VStack(spacing: 10) {
                floatingNavBar
                if isSending && showThinkingOverlayFlag {
                    ThinkingOverlay()
                        .padding(.top, 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
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
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            normalizeExistingMessagesIfNeeded()
            if isDefaultTitle, let first = sortedMessages.first {
                updateChatTitle(from: first.content)
            }
            showSuggestions = chat.messages.isEmpty
            dockController.expand(animated: false)
        }
        .onChange(of: chat.messages.count) { _, _ in
            hasNormalizedExistingMessages = false
            normalizeExistingMessagesIfNeeded()
        }
    }

    private func handleScrollChange(_ offset: CGFloat) {
        let distance = max(offset, 0)
        dockController.nudge(withScrollOffset: distance)
        if distance < 12 {
            dockController.expand(animated: true)
        }
    }

    private var showThinkingOverlayFlag: Bool {
        settingsQuery.first?.showThinkingOverlay ?? true
    }

    private var showReasoningSnippetsFlag: Bool {
        settingsQuery.first?.showReasoningSnippets ?? true
    }

    private var activeStreamingSnapshot: StreamingMarkdownSnapshot? {
        let snapshot = streamingMarkdown.snapshot
        return (snapshot.hasVisibleContent || snapshot.hasReasoningSummary) ? snapshot : nil
    }

    private var activeStreamingText: String? {
        guard activeStreamingSnapshot != nil else { return nil }
        return streamingMarkdown.combinedText.isEmpty ? nil : streamingMarkdown.combinedText
    }

    private var effectiveAIDisplayName: String {
        if let custom = settingsQuery.first?.aiDisplayName.trimmingCharacters(in: .whitespacesAndNewlines), custom.isEmpty == false {
            return custom
        }
        return providerDisplayName
    }

    private var userDisplayName: String {
        guard let settings = settingsQuery.first else { return "You" }
        let first = settings.userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.isEmpty == false { return first }
        let username = settings.userUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty == false { return username }
        let last = settings.userLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if last.isEmpty == false { return last }
        return "You"
    }

    // Split out heavy view builder to speed up type checking
    private struct MessageListView: View {
        let messages: [Message]
        let streamingSnapshot: StreamingMarkdownSnapshot?
        let isSending: Bool
        var aiDisplayName: String
        var aiModel: String
        var userDisplayName: String
        var showReasoningSnippets: Bool
        var bottomInset: CGFloat
        var streamingVersionIndex: Int? = nil
        var versionMeta: [UUID: AssistantVersionMeta] = [:]
        var onRetry: (Message) -> Void
        var onCopy: (Message) -> Void
        var onEdit: (Message) -> Void
        var onScroll: (CGFloat) -> Void
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            switch message.role {
                           case "assistant":
                                MessageRow(message: message,
                                           aiDisplayName: aiDisplayName,
                                           aiModel: aiModel,
                                           userDisplayName: userDisplayName,
                                           versionMeta: versionMeta[message.id],
                                           onRetry: { onRetry(message) },
                                           onCopy: { onCopy(message) })
                            case "user":
                                MessageRow(message: message,
                                           aiDisplayName: aiDisplayName,
                                           aiModel: aiModel,
                                           userDisplayName: userDisplayName,
                                           onEdit: { onEdit(message) })
                            case reasoningMessageRole:
                                if showReasoningSnippets {
                                    let snippet = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if snippet.isEmpty == false {
                                        ReasoningSummaryDisclosure(title: "\(aiDisplayName) — Reasoning",
                                                                   summary: snippet)
                                            .id(message.id)
                                    }
                                }
                            default:
                                MessageRow(message: message,
                                           aiDisplayName: aiDisplayName,
                                           aiModel: aiModel,
                                           userDisplayName: userDisplayName,
                                           onRetry: { onRetry(message) },
                                           onCopy: { onCopy(message) },
                                           onEdit: { onEdit(message) })
                            }
                        }
                        if let snapshot = streamingSnapshot, (snapshot.hasVisibleContent || snapshot.hasReasoningSummary) {
                            StreamingRow(snapshot: snapshot,
                                         aiDisplayName: aiDisplayName,
                                         aiModel: aiModel,
                                         versionIndex: streamingVersionIndex)
                                .id("streaming-row")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, bottomInset)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: max(0, -geo.frame(in: .named("chat.scroll")).minY)
                            )
                        }
                    )
                }
                .coordinateSpace(name: "chat.scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    onScroll(value)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: streamingSnapshot?.stableMarkdown ?? "") { _, newValue in
                    guard !newValue.isEmpty else { return }
                    withAnimation { proxy.scrollTo("streaming-row", anchor: .bottom) }
                }
                .onChange(of: streamingSnapshot?.tailRaw ?? "") { _, newValue in
                    guard !newValue.isEmpty else { return }
                    withAnimation { proxy.scrollTo("streaming-row", anchor: .bottom) }
                }
                .onChange(of: isSending) { _, sending in
                    if sending == false {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }

        private struct ScrollOffsetPreferenceKey: PreferenceKey {
            static var defaultValue: CGFloat = 0
            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = nextValue()
            }
        }
    }

    // Minimal glassy thinking overlay shown under the model name while streaming
    private struct ThinkingOverlay: View {
        @Environment(\.tokens) private var T
        @State private var phase: Double = 0
        var body: some View {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).opacity(opacity(0))
                    Circle().frame(width: 6, height: 6).opacity(opacity(1))
                    Circle().frame(width: 6, height: 6).opacity(opacity(2))
                }
                .foregroundStyle(T.accent)
                Text("Thinking…")
                    .font(.footnote)
                    .foregroundStyle(T.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(T.borderSoft, lineWidth: 0.7))
            .shadow(color: T.shadow.opacity(0.12), radius: 6, y: 2)
            .onAppear { withAnimation(.easeInOut(duration: 1.0).repeatForever()) { phase = 1 } }
        }
        private func opacity(_ i: Int) -> Double { max(0.25, 1 - abs(sin(phase * .pi + Double(i) * 0.8))) }
    }

    private struct MessageRow: View {
        let message: Message
        // For assistant header
        var aiDisplayName: String = "AI"
        var aiModel: String = ""
        var userDisplayName: String = "You"
        @Environment(\.tokens) private var T
        var versionMeta: AssistantVersionMeta? = nil
        var onRetry: (() -> Void)? = nil
        var onCopy: (() -> Void)? = nil
        var onEdit: (() -> Void)? = nil
        var body: some View {
            Group {
                if message.role == "user" {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(userDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
                    }
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            AppIcon.starsHeader(14)
                                .foregroundStyle(T.textSecondary)
                            Text("\(aiDisplayName) \(aiModel)")
                                .font(.footnote)
                                .foregroundStyle(T.textSecondary)
                        }
                        .padding(.top, 2)

                        AIResponseView(text: message.content)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button("Retry") { onRetry?() }
                            Button("Copy") { onCopy?() }
                            if let meta = versionMeta, meta.total > 1 {
                                Spacer(minLength: 8)
                                HStack(spacing: 8) {
                                    Button(action: meta.onPrevious) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .disabled(meta.current <= 1)
                                    Text("<\(meta.current)/\(meta.total)>")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(T.textSecondary)
                                    Button(action: meta.onNext) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .disabled(meta.current >= meta.total)
                                }
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(T.textSecondary)
                        .padding(.bottom, 2)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private struct ReasoningSummaryDisclosure: View {
        let title: String
        let summary: String
        @Environment(\.tokens) private var T
        @State private var expanded = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        AppIcon.starsHeader(14)
                            .foregroundStyle(T.accent)
                        Text(title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(T.textSecondary)
                        Spacer(minLength: 8)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(T.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Text(summary)
                    .font(.callout)
                    .foregroundStyle(T.textSecondary)
                    .lineLimit(expanded ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(T.borderSoft.opacity(0.9))
                    .frame(width: 2)
            }
        }
    }

    private struct StreamingRow: View {
        let snapshot: StreamingMarkdownSnapshot
        var aiDisplayName: String = "AI"
        var aiModel: String = ""
        var versionIndex: Int? = nil
        @Environment(\.tokens) private var T
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    AppIcon.starsHeader(14)
                        .foregroundStyle(T.textSecondary)
                    Text("\(aiDisplayName) \(aiModel)")
                        .font(.footnote)
                        .foregroundStyle(T.textSecondary)
                    if let idx = versionIndex, idx > 1 {
                        Text("v\(idx)")
                            .font(.caption)
                            .foregroundStyle(T.textSecondary)
                            .monospacedDigit()
                    }
                }
                AIResponseView(streaming: snapshot)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
        }
    }

    private var chatDisplayTitle: String {
        let trimmed = chat.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let firstUser = sortedMessages.first(where: { $0.role == "user" && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return String(firstUser.content.prefix(32)) + (firstUser.content.count > 32 ? "…" : "")
        }
        return "New Chat"
    }

    @ViewBuilder
    private var floatingNavBar: some View {
        HStack(spacing: 16) {
            modelMenuPill
                .accessibilityLabel("Model Picker")
                .accessibilityValue(currentModelDisplay())

            Spacer(minLength: 16)

            if canCreateChat {
                glassToolbarButton(systemName: "plus") {
                    onNewChat?()
                }
                .accessibilityLabel("New Chat")
            }
        }
    }

    private var modelMenuPill: some View {
        Menu {
            Section("Quick Models") {
                ForEach(quickModels(), id: \.self) { m in
                    Button(action: { setDefaultModel(m) }) {
                        HStack {
                            Text(m)
                            if m == (settingsQuery.first?.defaultModel ?? "") {
                                AppIcon.checkCircle(true, size: 14)
                            }
                        }
                    }
                }
            }
            Button("Other models…") { showFullModelPicker = true }
            Button("Provider defaults…") { showModelEditor = true }
            Divider()
            Button("Chat Settings…") { showChatSettings = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text(currentModelDisplay())
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .baselineOffset(-2)
            }
            .foregroundStyle(T.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(T.borderSoft.opacity(0.45), lineWidth: 0.7)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .shadow(color: T.shadow.opacity(0.12), radius: 10, y: 6)
    }

    private func currentModelDisplay() -> String {
        let s = settingsQuery.first
        return s?.defaultModel.isEmpty == false ? (s?.defaultModel ?? "Model") : "Model"
    }

    private var canCreateChat: Bool { onNewChat != nil }

    private var shouldShowBackButton: Bool { onNewChat == nil }

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
        persistContext()
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

    @ViewBuilder
    private func glassToolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(T.text)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(T.borderSoft.opacity(0.45), lineWidth: 0.7)
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: T.shadow.opacity(0.18), radius: 8, y: 6)
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
                        persist()
                    }
                    dismiss()
                }) {
                    HStack { Text(m); if m == (settingsQuery.first?.defaultModel ?? "") { AppIcon.checkCircle(true, size: 14) } }
                }
            }
        }

        private func persist() {
            do {
                try modelContext.save()
            } catch {
                print("ModelContext save failed in FullModelPickerSheet: \(error)")
            }
        }
    }

    @MainActor
    private struct ChatSettingsSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(SettingsStore.self) private var settingsStore
        @State private var systemPrompt: String = ""
        @State private var temperature: Double = 1.0
        @State private var maxTokens: Double = 8192
        @State private var historyLimit: Int = -1 // -1 = All
        var body: some View {
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
                    systemPrompt = settingsStore.systemPrompt
                    temperature = settingsStore.temperature
                    maxTokens = Double(settingsStore.maxTokens)
                    historyLimit = settingsStore.defaultHistoryLimit
                }
                .navigationTitle("Chat Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            settingsStore.systemPrompt = systemPrompt
                            settingsStore.temperature = temperature
                            settingsStore.maxTokens = Int(maxTokens)
                            settingsStore.defaultHistoryLimit = historyLimit
                            settingsStore.save()
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

    private var displayMessages: [Message] {
        var output: [Message] = []
        let userMessages = sortedMessages.filter { $0.role == "user" }
        for user in userMessages {
            let turnID = ensureTurnID(for: user)
            output.append(user)
            if let assistant = selectedAssistantMessage(for: user) {
                output.append(assistant)
                if showReasoningSnippetsFlag,
                   let snippet = reasoningMessage(for: turnID, version: assistant.versionIndex) {
                    output.append(snippet)
                }
            }
        }
        return output
    }

    private func normalizeExistingMessagesIfNeeded() {
        guard hasNormalizedExistingMessages == false else { return }
        let ordered = chat.messages.sorted(by: { $0.createdAt < $1.createdAt })
        if normalizeTurnMetadata(in: ordered) {
            persistContext()
        }
        hasNormalizedExistingMessages = true
    }

    private var assistantVersionMeta: [UUID: AssistantVersionMeta] {
        var map: [UUID: AssistantVersionMeta] = [:]
        let userMessages = sortedMessages.filter { $0.role == "user" }
        for user in userMessages {
            let turnID = ensureTurnID(for: user)
            let assistants = assistantMessages(for: turnID)
            guard !assistants.isEmpty else { continue }
            let total = assistants.count
            let currentIndex = normalizedSelectedIndex(for: user, total: total, messages: assistants)

            let sortedAssistants = assistants.sorted { $0.versionIndex < $1.versionIndex }
            guard let currentMessage = sortedAssistants.first(where: { $0.versionIndex == currentIndex }) ?? sortedAssistants.last else { continue }

            map[currentMessage.id] = AssistantVersionMeta(
                current: currentIndex,
                total: total,
                onPrevious: { stepVersion(for: turnID, delta: -1) },
                onNext: { stepVersion(for: turnID, delta: 1) }
            )
        }
        return map
    }

    private struct AssistantVersionMeta {
        let current: Int
        let total: Int
        let onPrevious: () -> Void
        let onNext: () -> Void
    }

    private var isDefaultTitle: Bool {
        chat.title.isEmpty || chat.title == "New Chat"
    }

    @MainActor
    private func send() async {
        guard !isSending else { return }
        defer { currentSendTask = nil }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        withAnimation { showSuggestions = false }

        var userMessage: Message
        var promptText: String
        var attachmentsToSend = attachments

        if let editing = editingMessage {
            promptText = trimmed
            guard !promptText.isEmpty else { return }
            editing.content = promptText
            editing.createdAt = Date()
            editing.selectedVersionIndex = 0
            if editing.turnID == nil { editing.turnID = editing.id }
            let msgs = sortedMessages
            if let idx = msgs.firstIndex(where: { $0.id == editing.id }) {
                for msg in msgs.suffix(from: idx + 1) {
                    modelContext.delete(msg)
                }
            }
            persistContext()
            userMessage = editing
            attachmentsToSend = []
        } else {
            guard !trimmed.isEmpty else { return }
            promptText = trimmed
            let turnIdentifier = UUID()
            let userMsg = Message(role: "user",
                                  content: promptText,
                                  chat: chat,
                                  turnID: turnIdentifier,
                                  versionIndex: 0,
                                  selectedVersionIndex: 0)
            modelContext.insert(userMsg)
            persistContext()
            userMessage = userMsg
        }

        inputText = ""
        retryingUserMessage = nil

        await performResponse(for: userMessage,
                              prompt: promptText,
                              attachments: attachmentsToSend)
    }

    @MainActor
    private func performResponse(for userMessage: Message,
                                 prompt: String,
                                 attachments attachmentsToSend: [(data: Data, mime: String)]) async {
        isSending = true
        streamingMarkdown.reset()
        errorMessage = nil
        let turnID = turnID(for: userMessage)
        activeTurnID = turnID
        pendingVersionIndex = nextVersionIndex(for: userMessage)

        let loggingEnabled = SettingsStore.shared?.logChatTranscripts ?? false
        var loggingContext: ChatLoggingContext?

        defer {
            isSending = false
            streamingMarkdown.reset()
            currentSendTask = nil
            editingMessage = nil
            retryingUserMessage = nil
            activeTurnID = nil
            pendingVersionIndex = 1
        }

        do {
            let settings = settingsQuery.first ?? AppSettings()
            let providerID = settings.defaultProvider
            let model = effectiveModel(for: providerID)

            loggingContext = ChatLoggingContext(chatID: chat.id,
                                                turnID: turnID,
                                                providerID: providerID,
                                                modelID: model,
                                                chatTitle: chat.title,
                                                extraMetadata: [:])

            let provider = try makeProvider(id: providerID)

            var aiMessages: [AIMessage] = []
            aiMessages.append(AIMessage(role: .system, content: MASTER_SYSTEM_PROMPT))
            let sys = settings.defaultSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if sys.isEmpty == false {
                aiMessages.append(AIMessage(role: .system, content: sys))
            }

            var history = conversationHistory(before: userMessage)
            let historyLimit = settings.defaultHistoryLimit
            if historyLimit > 0 && history.count > historyLimit {
                history = Array(history.suffix(historyLimit))
            }
            for item in history {
                guard item.role != reasoningMessageRole else { continue }
                let role: AIMessage.Role = (item.role == "user") ? .user : .assistant
                aiMessages.append(AIMessage(role: role, content: item.content))
            }

            var parts: [AIMessage.Part] = [.text(prompt)]
            var caps = ModelCapabilitiesStore.get(provider: providerID, model: model)
            let canSendImages = caps?.supportsImages ?? true
            if canSendImages {
                parts += attachmentsToSend.map { .imageData($0.data, mime: $0.mime) }
            } else if !attachmentsToSend.isEmpty {
                errorMessage = "This model doesn’t support image inputs. Images were omitted from the request."
            }
            aiMessages.append(AIMessage(role: .user, parts: parts))

            let wantsPromptCaching = settingsQuery.first?.promptCachingEnabled ?? false
            if caps?.enablePromptCaching == nil, wantsPromptCaching {
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

            if loggingEnabled {
                var instructionPieces: [String] = []
                let masterTrimmed = MASTER_SYSTEM_PROMPT.trimmingCharacters(in: .whitespacesAndNewlines)
                if masterTrimmed.isEmpty == false { instructionPieces.append(masterTrimmed) }
                if sys.isEmpty == false { instructionPieces.append(sys) }
                let instructionsText = instructionPieces.isEmpty ? nil : instructionPieces.joined(separator: "\n\n")
                let envelope = LoggingEnvelope(provider: providerID,
                                               model: model,
                                               instructions: instructionsText,
                                               temperature: tempEff,
                                               topP: topPEff,
                                               topK: topKEff,
                                               maxOutputTokens: finalMaxOut,
                                               reasoningEffort: reasoningEff,
                                               verbosity: verbosityEff,
                                               messages: aiMessages)
                ChatHistoryLogging.logEnvelope(envelope)
            }

            let performChat = { () async throws -> String in
                if let streaming = provider as? AIStreamingProvider {
                    streamingMarkdown.reset()
                    return try await streaming.streamChat(
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
                            streamingMarkdown.append(delta)
                        }
                        if loggingEnabled {
                            ChatHistoryLogging.logStreamChunk(delta, event: "delta")
                        }
                    } onReasoning: { summary in
                        Task { @MainActor in
                            streamingMarkdown.updateReasoningSummary(summary)
                        }
                        if loggingEnabled {
                            ChatHistoryLogging.logReasoning(summary)
                        }
                    }
                } else if let adv = provider as? AIProviderAdvanced {
                    return try await adv.sendChat(
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
                    return try await provider.sendChat(messages: aiMessages, model: model)
                }
            }

            let reply: String
            if loggingEnabled, let context = loggingContext {
                reply = try await ChatLoggingTaskLocal.$context.withValue(context) {
                    ChatHistoryLogging.beginTurn(metadata: [
                        "prompt": prompt,
                        "historyCount": String(history.count),
                        "attachments": String(attachmentsToSend.count)
                    ])
                    let responseText = try await performChat()
                    ChatHistoryLogging.logResponse(text: responseText)
                    return responseText
                }
            } else {
                reply = try await performChat()
            }

            insertAssistantReply(reply, reasoningSummary: streamingMarkdown.snapshot.reasoningSummary)

            if isDefaultTitle {
                updateChatTitle(from: prompt)
            }

            persistContext()
            attachments.removeAll()
        } catch is CancellationError {
            let partial = streamingMarkdown.combinedText
            if loggingEnabled, let context = loggingContext {
                if partial.isEmpty == false {
                    ChatHistoryLogger.shared.log(direction: .incoming,
                                                 kind: .response,
                                                 payload: .text(partial),
                                                 metadata: ["status": "cancelled"],
                                                 context: context)
                }
                ChatHistoryLogger.shared.log(direction: .incoming,
                                             kind: .info,
                                             payload: .text("Streaming cancelled"),
                                             metadata: ["reason": "user-initiated"],
                                             context: context)
            }
            if !partial.isEmpty {
                let summary = streamingMarkdown.snapshot.reasoningSummary
                streamingMarkdown.reset()
                insertAssistantReply(partial, reasoningSummary: summary)
                persistContext()
            }
            attachments.removeAll()
            errorMessage = nil
        } catch {
            if loggingEnabled, let context = loggingContext {
                ChatHistoryLogger.shared.logError((error as NSError).localizedDescription, context: context)
            }
            errorMessage = (error as NSError).localizedDescription
        }
    }

    // MARK: - Stop streaming
    @MainActor
    private func stopStreaming() {
        // Cancel the in-flight send task, if any.
        currentSendTask?.cancel()
        // If there's partial streamed content, finalize it as a message for continuity.
        let partial = streamingMarkdown.combinedText
        if !partial.isEmpty {
            let summary = streamingMarkdown.snapshot.reasoningSummary
            streamingMarkdown.reset()
            insertAssistantReply(partial, reasoningSummary: summary)
            persistContext()
        }
        isSending = false
        attachments.removeAll()
    }

    // MARK: - Provider header helpers
    private var providerDisplayName: String {
        let p = settingsQuery.first?.defaultProvider ?? "openai"
        return ProviderID(rawValue: p)?.displayName ?? "AI"
    }
    private var currentModel: String {
        settingsQuery.first?.defaultModel ?? ""
    }

    @MainActor
    private func insertAssistantReply(_ rawText: String, reasoningSummary: String? = nil) {
        guard let turnID = activeTurnID ?? retryingUserMessage?.turnID ?? retryingUserMessage?.id ?? editingMessage?.turnID ?? editingMessage?.id else {
            applyAssistantInsertion(rawText, turnID: UUID(), version: 1, reasoningSummary: reasoningSummary)
            return
        }
        let version = pendingVersionIndex
        applyAssistantInsertion(rawText, turnID: turnID, version: version, reasoningSummary: reasoningSummary)
    }

    @MainActor
    private func applyAssistantInsertion(_ rawText: String, turnID: UUID, version: Int, reasoningSummary: String?) {
        let processed: (snippet: String?, body: String)
        if let reasoningSummary, reasoningSummary.isEmpty == false {
            processed = (String(reasoningSummary.prefix(480)), rawText)
        } else {
            processed = extractReasoningSnippet(from: rawText)
        }
        if showReasoningSnippetsFlag, let snippet = processed.snippet {
            let reasoningMsg = Message(role: reasoningMessageRole,
                                       content: snippet,
                                       chat: chat,
                                       turnID: turnID,
                                       versionIndex: version)
            modelContext.insert(reasoningMsg)
        }
        let replyMessage = Message(role: "assistant",
                                   content: processed.body,
                                   chat: chat,
                                   turnID: turnID,
                                   versionIndex: version)
        modelContext.insert(replyMessage)
        if let user = userMessage(for: turnID) {
            user.selectedVersionIndex = version
            persistContext()
        }
    }

    private func extractReasoningSnippet(from rawText: String) -> (snippet: String?, body: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return (nil, rawText)
        }

        // Helpers to return once snippet located
        func finalize(snippet: Substring, remainder: Substring) -> (String?, String) {
            let snippetText = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyText = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            if bodyText.isEmpty {
                return (nil, trimmed)
            }
            let clippedSnippet: String
            if snippetText.count > 480 {
                clippedSnippet = String(snippetText.prefix(480)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                clippedSnippet = snippetText
            }
            return (clippedSnippet.isEmpty ? nil : clippedSnippet, String(bodyText))
        }

        // Case 1: <reasoning> ... </reasoning>
        if let open = trimmed.range(of: "<reasoning>", options: [.anchored, .caseInsensitive]),
           let close = trimmed.range(of: "</reasoning>", options: [.caseInsensitive], range: open.upperBound..<trimmed.endIndex) {
            let snippetRange = open.upperBound..<close.lowerBound
            let remainder = trimmed[close.upperBound..<trimmed.endIndex]
            return finalize(snippet: trimmed[snippetRange], remainder: remainder)
        }

        // Case 2: Reasoning:/Thought:/Thoughts: prefix
        let labelPrefixes = ["Reasoning:", "Thought:", "Thoughts:"]
        for label in labelPrefixes {
            if let labelRange = trimmed.range(of: label, options: [.anchored, .caseInsensitive]) {
                var afterLabel = trimmed[labelRange.upperBound..<trimmed.endIndex]
                if afterLabel.first == " " { afterLabel = afterLabel.dropFirst() }
                if let doubleBreak = afterLabel.range(of: "\n\n") {
                    let snippet = afterLabel[..<doubleBreak.lowerBound]
                    let remainder = afterLabel[doubleBreak.upperBound..<afterLabel.endIndex]
                    return finalize(snippet: snippet, remainder: remainder)
                } else {
                    // No clear remainder; keep original text to avoid empty reply
                    return (nil, trimmed)
                }
            }
        }

        // Case 3: ```reasoning fenced code block
        if let fenceStart = trimmed.range(of: "```reasoning", options: [.anchored, .caseInsensitive]) {
            var afterFence = trimmed[fenceStart.upperBound..<trimmed.endIndex]
            if afterFence.first == "\n" { afterFence = afterFence.dropFirst() }
            if let fenceEnd = afterFence.range(of: "```") {
                let snippet = afterFence[..<fenceEnd.lowerBound]
                let remainder = afterFence[fenceEnd.upperBound..<afterFence.endIndex]
                return finalize(snippet: snippet, remainder: remainder)
            }
        }

        return (nil, trimmed)
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
        if let s = settingsQuery.first { s.defaultModel = fallback; persistContext() }
        return fallback
    }

    private func turnID(for message: Message) -> UUID {
        message.turnID ?? message.id
    }

    private func assistantMessages(for turnID: UUID) -> [Message] {
        sortedMessages.filter { $0.role == "assistant" && self.turnID(for: $0) == turnID }
            .sorted(by: { $0.versionIndex < $1.versionIndex })
    }

    private func reasoningMessage(for turnID: UUID, version: Int) -> Message? {
        sortedMessages.first(where: { $0.role == reasoningMessageRole && self.turnID(for: $0) == turnID && $0.versionIndex == version })
    }

    private func selectedAssistantMessage(for user: Message) -> Message? {
        let assistants = assistantMessages(for: turnID(for: user))
        guard !assistants.isEmpty else { return nil }
        let index = normalizedSelectedIndex(for: user, total: assistants.count, messages: assistants)
        return assistants.first(where: { $0.versionIndex == index }) ?? assistants.last
    }

    private func normalizedSelectedIndex(for user: Message, total: Int, messages: [Message]) -> Int {
        let indices = messages.map { $0.versionIndex }.sorted()
        if total == 0 { return 0 }
        let selected = user.selectedVersionIndex
        if selected > 0, indices.contains(selected) {
            return selected
        }
        return indices.last ?? total
    }

    @MainActor
    private func stepVersion(for turnID: UUID, delta: Int) {
        guard let user = userMessage(for: turnID) else { return }
        let assistants = assistantMessages(for: turnID)
        guard !assistants.isEmpty else { return }
        let indices = assistants.map { $0.versionIndex }.sorted()
        let current = normalizedSelectedIndex(for: user, total: assistants.count, messages: assistants)
        guard let currentIdx = indices.firstIndex(of: current) else { return }
        let nextIdx = currentIdx + delta
        guard nextIdx >= 0, nextIdx < indices.count else { return }
        user.selectedVersionIndex = indices[nextIdx]
        persistContext()
    }

    private func userMessage(for turnID: UUID) -> Message? {
        sortedMessages.first(where: { $0.role == "user" && self.turnID(for: $0) == turnID })
    }

    private func ensureTurnID(for message: Message) -> UUID {
        if let turn = message.turnID { return turn }
        let assigned = message.id
        message.turnID = assigned
        return assigned
    }

    private func nextVersionIndex(for userMessage: Message) -> Int {
        let turnID = turnID(for: userMessage)
        let existing = assistantMessages(for: turnID)
        return (existing.map { $0.versionIndex }.max() ?? 0) + 1
    }

    private func conversationHistory(before target: Message) -> [Message] {
        let userMessages = sortedMessages.filter { $0.role == "user" }
        var history: [Message] = []
        for user in userMessages {
            if user.id == target.id { break }
            history.append(user)
            if let assistant = selectedAssistantMessage(for: user) {
                history.append(assistant)
            }
        }
        return history
    }

    @MainActor
    private func normalizeTurnMetadata(in messages: [Message]) -> Bool {
        var currentTurnID: UUID?
        var currentVersionCounter: Int = 0
        var didChange = false
        for message in messages {
            switch message.role {
            case "user":
                let turn = message.turnID ?? message.id
                if message.turnID == nil { didChange = true }
                message.turnID = turn
                currentTurnID = turn
                currentVersionCounter = 0
                if message.selectedVersionIndex == 0 {
                    message.selectedVersionIndex = 1
                    didChange = true
                }
            case "assistant":
                if message.turnID == nil {
                    message.turnID = currentTurnID ?? UUID()
                    didChange = true
                }
                if message.versionIndex == 0 {
                    currentVersionCounter += 1
                    message.versionIndex = currentVersionCounter
                    didChange = true
                } else {
                    currentVersionCounter = max(currentVersionCounter, message.versionIndex)
                }
            case reasoningMessageRole:
                if message.turnID == nil {
                    message.turnID = currentTurnID ?? UUID()
                    didChange = true
                }
                if message.versionIndex == 0 {
                    message.versionIndex = max(1, currentVersionCounter)
                    didChange = true
                }
            default:
                continue
            }
        }
        return didChange
    }

    @State private var showModelEditor: Bool = false
    @State private var showFullModelPicker: Bool = false
    @State private var showChatSettings: Bool = false

    private func updateChatTitle(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        chat.title = String(trimmed.prefix(40))
        persistContext()
    }

    @MainActor
    private func persistContext() {
        do {
            try modelContext.save()
        } catch {
            let nsError = error as NSError
            errorMessage = nsError.localizedDescription
            print("ModelContext save failed: \(nsError), userInfo: \(nsError.userInfo)")
        }
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

    // MARK: - Message actions
    private func retryResponse(_ message: Message) async {
        guard !isSending else { return }
        let turn = turnID(for: message)
        guard let user = userMessage(for: turn) else { return }
        retryingUserMessage = user
        await performResponse(for: user,
                              prompt: user.content,
                              attachments: [])
    }

    private func copyResponse(_ message: Message) {
        UIPasteboard.general.string = message.content
    }

    private func editMessage(_ message: Message) {
        editingMessage = message
        inputText = message.content
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
    func downscaledJPEGData(from image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.85) -> Data? {
        let targetSize: CGSize
        if max(image.size.width, image.size.height) <= maxDimension {
            targetSize = image.size
        } else {
            let scale = maxDimension / max(image.size.width, image.size.height)
            targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaled.jpegData(compressionQuality: quality)
    }

    if let type = item.supportedContentTypes.first {
        if type.conforms(to: .jpeg) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            return (data, "image/jpeg")
        } else if type.conforms(to: .png) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            return (data, "image/png")
        } else if type.conforms(to: .heic) || type.conforms(to: .heif) {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "Photos", code: -1) }
            if let image = UIImage(data: data), let jpeg = downscaledJPEGData(from: image) {
                return (jpeg, "image/jpeg")
            }
        }
    }
    if let rawData = try await item.loadTransferable(type: Data.self) {
        if let image = UIImage(data: rawData), let jpeg = image.jpegData(compressionQuality: 0.85) {
            return (jpeg, "image/jpeg")
        }
        return (rawData, "image/jpeg")
    }
    throw NSError(domain: "Photos", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not load image data"]) 
}
