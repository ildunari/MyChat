// Views/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var store
    @Environment(\.tokens) private var T

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                List {
                Section {
                    NavigationLink {
                        ProvidersSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            AppIcon.info(18).foregroundStyle(T.accent)
                            VStack(alignment: .leading) {
                                Text("Providers")
                                Text("Manage API keys and models").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        DefaultChatSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            AppIcon.info(18).foregroundStyle(T.accent)
                            VStack(alignment: .leading) {
                                Text("Default Chat")
                                Text("System prompt, temperature, tokens").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Interface") {
                    NavigationLink {
                        InterfaceSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            AppIcon.info(18).foregroundStyle(T.accent)
                            VStack(alignment: .leading) {
                                Text("Appearance")
                                Text("Theme, font, text size, bubble colors").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        PersonalizationSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            AppIcon.user(18).foregroundStyle(T.accent)
                            VStack(alignment: .leading) {
                                Text("Personalization")
                                Text("Your name, username, AI name, personal info").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Toggle(isOn: $store.useWebCanvas) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Web Canvas")
                            Text("Faster rendering with streaming, math, tables, code, artifacts slot").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: store.useWebCanvas) { _, _ in store.save() }
                }
                Section("Defaults") {
                    Picker("Default Provider", selection: $store.defaultProvider) {
                        Text("OpenAI").fontWeight(.semibold).tag("openai")
                        Text("Anthropic").fontWeight(.semibold).tag("anthropic")
                        Text("Google").fontWeight(.semibold).tag("google")
                        Text("XAI").fontWeight(.semibold).tag("xai")
                    }
                    .fontWeight(.semibold)
                    .onChange(of: store.defaultProvider) { _, _ in store.save() }

                    // Model picker based on enabled models for the selected provider
                    Picker("Default Model", selection: $store.defaultModel) {
                        ForEach(modelsForSelectedProvider(), id: \.self) { m in
                            Text(m).fontWeight(.semibold).tag(m)
                        }
                    }
                    .fontWeight(.semibold)
                    .pickerStyle(.menu)
                    .disabled(modelsForSelectedProvider().isEmpty)
                    .onChange(of: store.defaultModel) { _, _ in store.save() }
                    .onAppear { ensureValidDefaultModel() }
                    .onChange(of: store.defaultProvider) { _, _ in ensureValidDefaultModel() }
                    .onChange(of: store.openAIEnabled) { _, _ in if store.defaultProvider == "openai" { ensureValidDefaultModel() } }
                    .onChange(of: store.anthropicEnabled) { _, _ in if store.defaultProvider == "anthropic" { ensureValidDefaultModel() } }
                    .onChange(of: store.googleEnabled) { _, _ in if store.defaultProvider == "google" { ensureValidDefaultModel() } }
                    .onChange(of: store.xaiEnabled) { _, _ in if store.defaultProvider == "xai" { ensureValidDefaultModel() } }
                }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .background(.clear)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
                )
            }
            .navigationTitle("Settings")
            .toolbar {
                // Only show Save button if there are unsaved changes
                if store.hasUnsavedChanges {
                    ToolbarItem(placement: .confirmationAction) { 
                        Button("Save") { 
                            store.save()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}

// MARK: - SettingsView helpers
private extension SettingsView {
    func modelsForSelectedProvider() -> [String] {
        switch store.defaultProvider {
        case "openai": return Array(store.openAIEnabled).sorted()
        case "anthropic": return Array(store.anthropicEnabled).sorted()
        case "google": return Array(store.googleEnabled).sorted()
        case "xai": return Array(store.xaiEnabled).sorted()
        default: return []
        }
    }

    func ensureValidDefaultModel() {
        let models = modelsForSelectedProvider()
        if models.contains(store.defaultModel) == false {
            store.defaultModel = models.first ?? ""
        }
    }
}

// MARK: - Personalization
private struct PersonalizationSettingsView: View {
    @Environment(SettingsStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Form {
            Section("Identity") {
                TextField("First Name", text: $store.userFirstName)
                    .onChange(of: store.userFirstName) { _, _ in store.save() }
                TextField("Last Name", text: $store.userLastName)
                    .onChange(of: store.userLastName) { _, _ in store.save() }
                TextField("Username", text: $store.userUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: store.userUsername) { _, _ in store.save() }
            }
            Section("Assistant") {
                TextField("AI Name (assistant)", text: $store.aiName)
                    .onChange(of: store.aiName) { _, _ in store.save() }
            }
            Section("Personal Info") {
                TextEditor(text: $store.personalInfo)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle("Personalization")
    }
}

private struct ProvidersSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        List {
            ProviderRow(title: ProviderID.openai.displayName, iconView: AnyView(AppIcon.providerOpenAI(16))) {
                ProviderDetailView(provider: .openai)
            }
            ProviderRow(title: ProviderID.anthropic.displayName, iconView: AnyView(AppIcon.providerAnthropic(16))) {
                ProviderDetailView(provider: .anthropic)
            }
            ProviderRow(title: ProviderID.google.displayName, iconView: AnyView(AppIcon.providerGoogle(16))) {
                ProviderDetailView(provider: .google)
            }
            ProviderRow(title: ProviderID.xai.displayName, iconView: AnyView(AppIcon.providerXAI(16))) {
                ProviderDetailView(provider: .xai)
            }
        }
        .navigationTitle("Providers")
    }
}

private struct ProviderRow<Destination: View>: View {
    let title: String
    let iconView: AnyView
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                iconView
                    .foregroundStyle(.teal)
                Text(title)
            }
        }
    }
}

private struct ProviderDetailView: View {
    let provider: ProviderID
    @Environment(SettingsStore.self) private var store
    @State private var apiKey: String = ""
    @State private var available: [String] = []
    @State private var verifying = false
    @State private var verified: Bool? = nil
    @State private var loadingModels = false
    private struct SelectedModel: Identifiable { let id: String }
    @State private var activeModelForEdit: SelectedModel? = nil

    var body: some View {
        Form {
            Section(header: Text(provider.displayName)) {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, _ in 
                        writeAPIKey(apiKey)
                    }
                VerificationBar(verifying: verifying, verified: verified)
                HStack {
                    Button {
                        Task { await verify() }
                    } label: {
                        HStack(spacing: 6) {
                            AppIcon.refresh(14)
                            Text("Verify")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        Task { await reloadModels() }
                    } label: {
                        HStack(spacing: 6) {
                            AppIcon.refreshModels(14)
                            Text("Refresh Models")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingModels)
                }
            }

            Section("Select Models (shown in picker)") {
                if loadingModels {
                    HStack { ProgressView(); Text("Loading…") }
                } else if available.isEmpty {
                    Text("No models. Verify API key and refresh.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available, id: \.self) { m in
                        ModelRowWithInfo(title: m,
                                         isOn: bindingForModel(m),
                                         onInfo: { activeModelForEdit = SelectedModel(id: m) })
                    }
                }
            }
        }
        .navigationTitle(provider.displayName)
        .sheet(item: $activeModelForEdit) { selected in
            ModelSettingsView(providerID: provider.rawValue, modelID: selected.id)
        }
        .onAppear {
            apiKey = readAPIKey()
            available = enabledModelsAll()
        }
    }

    private func bindingForModel(_ m: String) -> Binding<Bool> {
        switch provider {
        case .openai:
            return Binding(
                get: { store.openAIEnabled.contains(m) },
                set: { v in 
                    if v { _ = store.openAIEnabled.insert(m) } else { _ = store.openAIEnabled.remove(m) }
                    store.save()
                }
            )
        case .anthropic:
            return Binding(
                get: { store.anthropicEnabled.contains(m) },
                set: { v in 
                    if v { _ = store.anthropicEnabled.insert(m) } else { _ = store.anthropicEnabled.remove(m) }
                    store.save()
                }
            )
        case .google:
            return Binding(
                get: { store.googleEnabled.contains(m) },
                set: { v in 
                    if v { _ = store.googleEnabled.insert(m) } else { _ = store.googleEnabled.remove(m) }
                    store.save()
                }
            )
        case .xai:
            return Binding(
                get: { store.xaiEnabled.contains(m) },
                set: { v in 
                    if v { _ = store.xaiEnabled.insert(m) } else { _ = store.xaiEnabled.remove(m) }
                    store.save()
                }
            )
        }
    }

    private func enabledModelsAll() -> [String] {
        switch provider {
        case .openai: return Array(store.openAIEnabled).sorted()
        case .anthropic: return Array(store.anthropicEnabled).sorted()
        case .google: return Array(store.googleEnabled).sorted()
        case .xai: return Array(store.xaiEnabled).sorted()
        }
    }

    private func readAPIKey() -> String {
        switch provider {
        case .openai: return store.openAIAPIKey
        case .anthropic: return store.anthropicAPIKey
        case .google: return store.googleAPIKey
        case .xai: return store.xaiAPIKey
        }
    }

    private func writeAPIKey(_ value: String) {
        switch provider {
        case .openai: store.openAIAPIKey = value
        case .anthropic: store.anthropicAPIKey = value
        case .google: store.googleAPIKey = value
        case .xai: store.xaiAPIKey = value
        }
    }

    private func verify() async {
        verified = nil
        verifying = true
        let ok = await ProviderAPIs.verifyKey(provider: provider, apiKey: apiKey)
        if ok {
            // Populate model info on successful verify
            do {
                let infos = try await ProviderAPIs.listModelInfos(provider: provider, apiKey: apiKey)
                await MainActor.run {
                    ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
                    self.available = infos.map { $0.id }
                    // If defaults target this provider, clamp tokens to model limit when possible
                    if store.defaultProvider == provider.rawValue,
                       let cap = infos.first(where: { $0.id == store.defaultModel }),
                       let out = cap.outputTokenLimit {
                        store.maxTokens = min(store.maxTokens, out)
                    }
                }
            } catch {
                // ignore; keep simple list population as fallback
            }
        }
        await MainActor.run { verified = ok; verifying = false }
    }

    private func reloadModels() async {
        loadingModels = true
        do {
            let infos = try await ProviderAPIs.listModelInfos(provider: provider, apiKey: apiKey)
            await MainActor.run {
                ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
                let models = infos.map { $0.id }
                self.available = models
                if models.isEmpty == false { // seed enabled set if empty
                    switch provider {
                    case .openai: if store.openAIEnabled.isEmpty { store.openAIEnabled = Set(models.prefix(5)) }
                    case .anthropic: if store.anthropicEnabled.isEmpty { store.anthropicEnabled = Set(models.prefix(5)) }
                    case .google: if store.googleEnabled.isEmpty { store.googleEnabled = Set(models.prefix(5)) }
                    case .xai: if store.xaiEnabled.isEmpty { store.xaiEnabled = Set(models.prefix(5)) }
                    }
                }
                if store.defaultProvider == provider.rawValue,
                   let cap = infos.first(where: { $0.id == store.defaultModel }),
                   let out = cap.outputTokenLimit {
                    store.maxTokens = min(store.maxTokens, out)
                }
            }
        } catch {
            // Fallback to simple list
            do {
                let models = try await ProviderAPIs.listModels(provider: provider, apiKey: apiKey)
                await MainActor.run { self.available = models }
            } catch {
                await MainActor.run { self.available = [] }
            }
        }
        loadingModels = false
    }
}

private struct ModelRowWithInfo: View {
    let title: String
    @Binding var isOn: Bool
    var onInfo: () -> Void
    @Environment(\.tokens) private var T
    var body: some View {
        HStack {
            Button(action: { isOn.toggle() }) {
                HStack {
                    AppIcon.checkCircle(isOn, size: 18)
                        .foregroundStyle(isOn ? T.accent : .secondary)
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            Button(action: onInfo) {
                AppIcon.info(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Model Info")
        }
    }
}

private struct VerificationBar: View {
    let verifying: Bool
    let verified: Bool?
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 6)
            if verifying {
                Capsule().fill(Color.green).frame(width: 60).opacity(0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: verifying)
            } else if let ok = verified {
                Capsule().fill(ok ? Color.green : Color.red).frame(maxWidth: .infinity).opacity(0.6)
            }
        }
        .padding(.top, 4)
    }
}

private struct DefaultChatSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var tempLocal: Double = 1.0
    @State private var tokensLocal: Double = 1024

    var body: some View {
        @Bindable var store = store
        Form {
            Section("System Prompt") {
                TextEditor(text: $store.systemPrompt)
                    .frame(minHeight: 120)
            }
            Section("Sampling") {
                VStack(alignment: .leading) {
                    HStack { Text("Temperature"); Spacer(); Text(String(format: "%.2f", store.temperature)).foregroundStyle(.secondary) }
                    Slider(value: $store.temperature, in: 0...maxTemperature, step: 0.05)
                }
                VStack(alignment: .leading) {
                    HStack { Text("Max Tokens"); Spacer(); Text("\(store.maxTokens)").foregroundStyle(.secondary) }
                    Slider(value: Binding(get: { Double(store.maxTokens) }, set: { 
                        store.maxTokens = Int($0)
                    }), in: 64...maxTokens, step: 32)
                }
                if supportsPromptCaching {
                    Toggle(isOn: $store.promptCachingEnabled) {
                        HStack(spacing: 6) {
                            AppIcon.lightning(14)
                            Text("Enable prompt caching (if supported)")
                        }
                    }
                    .onChange(of: store.promptCachingEnabled) { _, _ in store.save() }
                }
            }
        }
        .navigationTitle("Default Chat")
    }

    // Dynamic limits derived from Provider→Model capability cache
    private var caps: ProviderModelInfo? {
        ModelCapabilitiesStore.get(provider: store.defaultProvider, model: store.defaultModel)
    }
    private var maxTemperature: Double { caps?.maxTemperature ?? 2.0 }
    private var maxTokens: Double { Double(caps?.outputTokenLimit ?? 8192) }
    private var supportsPromptCaching: Bool { caps?.supportsPromptCaching ?? false }
}

// MARK: - Model Settings Editor

struct ModelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var T

    let providerID: String
    let modelID: String

    // Working copy
    @State private var displayName: String = ""
    @State private var inputTokenLimit: String = "" // use text to allow empty
    @State private var outputTokenLimit: String = ""
    @State private var maxTemperature: Double = 2.0
    @State private var supportsPromptCaching: Bool = false
    // Advanced prefs
    @State private var preferredTemperature: Double? = nil
    @State private var preferredTopP: Double? = nil
    @State private var preferredTopK: String = "" // text field
    @State private var preferredMaxOutputTokens: String = ""
    @State private var preferredReasoningEffort: String? = nil // none|low|medium|high
    @State private var preferredVerbosity: String? = nil // none|low|medium|high
    @State private var disableSafetyFilters: Bool = true
    @State private var preferredPresencePenalty: Double = 0
    @State private var preferredFrequencyPenalty: Double = 0
    @State private var stopSequences: String = "" // comma-separated
    // Anthropic specifics
    @State private var anthropicThinkingEnabled: Bool = false
    @State private var anthropicThinkingBudget: String = ""
    @State private var enablePromptCaching: Bool = false

    // Originals for discard detection
    @State private var original: ProviderModelInfo = .fallback(id: "")
    @State private var defaults: ProviderModelInfo = .fallback(id: "")
    @State private var showingDiscard: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Restore Default") { restoreDefault() }
                        .buttonStyle(.plain)
                        .foregroundStyle(T.accent)
                }

                Section("Model") {
                    HStack { Text("ID"); Spacer(); Text(modelID).foregroundStyle(.secondary) }
                    TextField("Display Name", text: $displayName)
                }

                Section("Limits") {
                    TextField("Input Token Limit", text: $inputTokenLimit)
                        .keyboardType(.numberPad)
                    TextField("Output Token Limit", text: $outputTokenLimit)
                        .keyboardType(.numberPad)
                    VStack(alignment: .leading) {
                        HStack { Text("Max Temperature"); Spacer(); Text(String(format: "%.2f", maxTemperature)).foregroundStyle(.secondary) }
                        Slider(value: $maxTemperature, in: 0...4, step: 0.05)
                    }
                    Toggle("Supports Prompt Caching", isOn: $supportsPromptCaching)
                }

                Section("Advanced Defaults (Applied on Send)") {
                    VStack(alignment: .leading) {
                        HStack { Text("Preferred Temperature"); Spacer(); Text(String(format: "%.2f", (preferredTemperature ?? maxTemperature))).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { preferredTemperature ?? maxTemperature }, set: { preferredTemperature = $0 }), in: 0...maxTemperature, step: 0.05)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Top P"); Spacer(); Text(String(format: "%.2f", preferredTopP ?? 1.0)).foregroundStyle(.secondary) }
                        Slider(value: Binding(get: { preferredTopP ?? 1.0 }, set: { preferredTopP = $0 }), in: 0...1, step: 0.01)
                    }
                    TextField("Top K", text: $preferredTopK)
                        .keyboardType(.numberPad)
                    TextField("Preferred Max Output Tokens", text: $preferredMaxOutputTokens)
                        .keyboardType(.numberPad)
                    // Penalties (OpenAI/XAI style)
                    VStack(alignment: .leading) {
                        HStack { Text("Presence Penalty"); Spacer(); Text(String(format: "%.2f", preferredPresencePenalty)).foregroundStyle(.secondary) }
                        Slider(value: $preferredPresencePenalty, in: -2...2, step: 0.1)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Frequency Penalty"); Spacer(); Text(String(format: "%.2f", preferredFrequencyPenalty)).foregroundStyle(.secondary) }
                        Slider(value: $preferredFrequencyPenalty, in: -2...2, step: 0.1)
                    }
                    TextField("Stop Sequences (comma-separated)", text: $stopSequences)
                    Picker("Reasoning Effort", selection: Binding(get: { preferredReasoningEffort ?? "none" }, set: { preferredReasoningEffort = ($0 == "none" ? nil : $0) })) {
                        Text("None").tag("none")
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    Picker("Verbosity", selection: Binding(get: { preferredVerbosity ?? "none" }, set: { preferredVerbosity = ($0 == "none" ? nil : $0) })) {
                        Text("None").tag("none")
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    Toggle("Disable Google Safety Filters", isOn: $disableSafetyFilters)
                    // Anthropic extras
                    Toggle("Anthropic Thinking Enabled", isOn: $anthropicThinkingEnabled)
                    TextField("Anthropic Thinking Budget (tokens)", text: $anthropicThinkingBudget)
                        .keyboardType(.numberPad)
                    Toggle("Enable Prompt Caching (Anthropic)", isOn: $enablePromptCaching)
                }

                if let defText = defaultSummary() {
                    Section("Current Defaults (from API)") {
                        Text(defText).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Model Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { attemptDismiss() } label: { AppIcon.close(16) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        let pair = ModelCapabilitiesStore.getPair(provider: providerID, model: modelID)
        let effective = ModelCapabilitiesStore.get(provider: providerID, model: modelID) ?? .fallback(id: modelID)
        defaults = pair.defaults ?? .fallback(id: modelID)
        original = effective

        displayName = effective.displayName ?? ""
        inputTokenLimit = effective.inputTokenLimit.map { String($0) } ?? ""
        outputTokenLimit = effective.outputTokenLimit.map { String($0) } ?? ""
        maxTemperature = effective.maxTemperature ?? 2.0
        supportsPromptCaching = effective.supportsPromptCaching ?? false
        preferredTemperature = effective.preferredTemperature
        preferredTopP = effective.preferredTopP
        preferredTopK = effective.preferredTopK.map { String($0) } ?? ""
        preferredMaxOutputTokens = effective.preferredMaxOutputTokens.map { String($0) } ?? ""
        preferredReasoningEffort = effective.preferredReasoningEffort
        preferredVerbosity = effective.preferredVerbosity
        disableSafetyFilters = effective.disableSafetyFilters ?? true
        preferredPresencePenalty = effective.preferredPresencePenalty ?? 0
        preferredFrequencyPenalty = effective.preferredFrequencyPenalty ?? 0
        stopSequences = (effective.stopSequences ?? []).joined(separator: ", ")
        anthropicThinkingEnabled = effective.anthropicThinkingEnabled ?? false
        anthropicThinkingBudget = effective.anthropicThinkingBudget.map { String($0) } ?? ""
        enablePromptCaching = effective.enablePromptCaching ?? false
    }

    private func currentInfo() -> ProviderModelInfo {
        ProviderModelInfo(
            id: modelID,
            displayName: displayName.isEmpty ? nil : displayName,
            inputTokenLimit: Int(inputTokenLimit),
            outputTokenLimit: Int(outputTokenLimit),
            maxTemperature: maxTemperature,
            supportsPromptCaching: supportsPromptCaching,
            preferredTemperature: preferredTemperature,
            preferredTopP: preferredTopP,
            preferredTopK: Int(preferredTopK),
            preferredMaxOutputTokens: Int(preferredMaxOutputTokens),
            preferredReasoningEffort: preferredReasoningEffort,
            preferredVerbosity: preferredVerbosity,
            disableSafetyFilters: disableSafetyFilters,
            preferredPresencePenalty: preferredPresencePenalty,
            preferredFrequencyPenalty: preferredFrequencyPenalty,
            stopSequences: stopSequences.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter{ !$0.isEmpty },
            anthropicThinkingEnabled: anthropicThinkingEnabled,
            anthropicThinkingBudget: Int(anthropicThinkingBudget),
            enablePromptCaching: enablePromptCaching
        )
    }

    private func hasUnsavedChanges() -> Bool {
        currentInfo() != original
    }

    private func attemptDismiss() {
        if hasUnsavedChanges() { showingDiscard = true } else { dismiss() }
    }

    private func saveAndDismiss() {
        let info = currentInfo()
        ModelCapabilitiesStore.putUser(provider: providerID, model: modelID, info: info)
        dismiss()
    }

    private func restoreDefault() {
        ModelCapabilitiesStore.clearUser(provider: providerID, model: modelID)
        load()
    }

    private func defaultSummary() -> String? {
        guard let d = ModelCapabilitiesStore.getPair(provider: providerID, model: modelID).defaults else { return nil }
        let input = d.inputTokenLimit.map(String.init) ?? "—"
        let output = d.outputTokenLimit.map(String.init) ?? "—"
        let temp = String(format: "%.2f", d.maxTemperature ?? 2.0)
        let caching = (d.supportsPromptCaching ?? false) ? "Yes" : "No"
        let tp = d.preferredTopP.map { String(format: "%.2f", $0) } ?? "—"
        let tk = d.preferredTopK.map(String.init) ?? "—"
        return "Input: \(input) • Output: \(output) • Max Temp: \(temp) • TopP: \(tp) • TopK: \(tk) • Caching: \(caching)"
    }
}

// MARK: - Interface Settings

private struct InterfaceSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var sizeIndex: Double = 2

    private let sizeLabels = ["XS", "S", "M", "L", "XL"]
    // already has colorScheme above; do not redeclare

    private var previewFont: Font {
        switch store.interfaceFontStyle {
        case "serif": return .system(.body, design: .serif)
        case "rounded": return .system(.body, design: .rounded)
        case "mono": return .system(.body, design: .monospaced)
        default: return .system(.body, design: .default)
        }
    }

    private func fontForIndex(_ idx: Int) -> Font {
        let base: Font
        switch store.interfaceFontStyle {
        case "serif": base = .system(.body, design: .serif)
        case "rounded": base = .system(.body, design: .rounded)
        case "mono": base = .system(.body, design: .monospaced)
        default: base = .system(.body, design: .default)
        }
        // Map to discrete sizes
        switch idx {
        case 0: return base.smallCaps().weight(.regular)
        case 1: return base
        case 2: return .system(size: 17, weight: .regular, design: baseDesign())
        case 3: return .system(size: 20, weight: .regular, design: baseDesign())
        default: return .system(size: 24, weight: .regular, design: baseDesign())
        }
    }

    private func baseDesign() -> Font.Design {
        switch store.interfaceFontStyle {
        case "serif": return .serif
        case "rounded": return .rounded
        case "mono": return .monospaced
        default: return .default
        }
    }

    // Reduced, distinct palettes with dark-mode variants via ThemeFactory
    private let paletteOptions: [(style: AppThemeStyle, label: String)] = [
        (.terracotta, "Terracotta"), (.sand, "Sand"), (.coolSlate, "Cool Slate"),
        (.lavender, "Lavender"), (.ocean, "Ocean"), (.forest, "Forest"),
        (.highContrast, "High Contrast")
    ]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Theme") {
                Picker("Color Scheme", selection: $store.interfaceTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: store.interfaceTheme) { _, _ in store.save() }
                Text("Choose whether the app follows system appearance or forces light/dark.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Font") {
                // Fancy two-column card grid for font choices
                let options: [(id: String, label: String)] = [
                    ("system", "System"), ("serif", "Serif"), ("rounded", "Rounded"), ("mono", "Monospaced")
                ]
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(options, id: \.id) { opt in
                        let titleF = cardTitleFont(for: opt.id)
                        let bodyF = cardBodyFont(for: opt.id)
                        let bg = cardBackground(for: opt.id)
                        FontOptionCard(
                            label: opt.label,
                            titleFont: titleF,
                            bodyFont: bodyF,
                            background: bg,
                            selected: store.interfaceFontStyle == opt.id,
                            onSelect: { 
                                store.interfaceFontStyle = opt.id
                                store.save()
                            }
                        )
                        .fontDesign(.default) // ensure preview cards show their own design, not the global selection
                        .accessibilityLabel("\(opt.label) font")
                        .accessibilityAddTraits(store.interfaceFontStyle == opt.id ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Text Size"); Spacer(); Text(sizeLabels[Int(store.interfaceTextSizeIndex)]) }
                    Slider(value: Binding(get: { Double(store.interfaceTextSizeIndex) }, set: { 
                        store.interfaceTextSizeIndex = Int($0.rounded())
                        store.save()
                    }), in: 0...4, step: 1)
                    // Previews under the slider positions
                    HStack(spacing: 12) {
                        ForEach(0..<5) { i in
                            VStack {
                                Text("Aa")
                                    .font(fontForIndex(i))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(i == store.interfaceTextSizeIndex ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(i == store.interfaceTextSizeIndex ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture { 
                                store.interfaceTextSizeIndex = i
                                store.save()
                            }
                        }
                    }
                }
            }

            Section("Theme Palette") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(paletteOptions, id: \.style) { opt in
                        PaletteOptionCard(
                            style: opt.style,
                            label: opt.label,
                            selected: store.chatBubbleColorID.lowercased() == opt.style.rawValue.lowercased(),
                            onSelect: {
                                store.chatBubbleColorID = opt.style.rawValue
                                store.save()
                            }
                        )
                        .accessibilityLabel("\(opt.label) palette")
                        .accessibilityAddTraits(store.chatBubbleColorID.lowercased() == opt.style.rawValue.lowercased() ? .isSelected : [])
                    }
                }
                Text("Soft, distinct palettes (with dark-mode variants). ‘Sand’ matches a Claude-like pastel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Appearance")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Restore Defaults") {
                    store.interfaceTheme = "system"
                    store.interfaceFontStyle = "rounded"
                    store.interfaceTextSizeIndex = 2
                    store.chatBubbleColorID = "coolSlate"
                    store.save()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            sizeIndex = Double(store.interfaceTextSizeIndex)
        }
    }

    // MARK: - Helpers (Fonts & Backgrounds)
    private func cardTitleFont(for id: String) -> Font {
        switch id {
        case "serif": return .system(size: 22, weight: .semibold, design: .serif)
        case "rounded": return .system(size: 22, weight: .semibold, design: .rounded)
        case "mono": return .system(size: 22, weight: .semibold, design: .monospaced)
        default: return .system(size: 22, weight: .semibold, design: .default)
        }
    }

    private func cardBodyFont(for id: String) -> Font {
        switch id {
        case "serif": return .system(size: 14, weight: .regular, design: .serif)
        case "rounded": return .system(size: 14, weight: .regular, design: .rounded)
        case "mono": return .system(size: 14, weight: .regular, design: .monospaced)
        default: return .system(size: 14, weight: .regular, design: .default)
        }
    }

    private func cardBackground(for id: String) -> Color {
        // Muted, per-font tones; adjusted for dark/light
        let isDark = (colorScheme == .dark)
        switch id {
        case "serif": return isDark ? Color(red: 0.18, green: 0.17, blue: 0.15) : Color(red: 0.97, green: 0.96, blue: 0.93)
        case "rounded": return isDark ? Color(red: 0.12, green: 0.16, blue: 0.20) : Color(red: 0.93, green: 0.96, blue: 0.98)
        case "mono": return isDark ? Color(red: 0.16, green: 0.16, blue: 0.22) : Color(red: 0.94, green: 0.94, blue: 0.98)
        default: return isDark ? Color.white.opacity(0.06) : Color.secondary.opacity(0.12)
        }
    }

}

// Split out to keep the parent body simple for the compiler
private struct PaletteOptionCard: View {
    let style: AppThemeStyle
    let label: String
    let selected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = ThemeFactory.make(style: style, colorScheme: colorScheme)
        return Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tokens.accent, tokens.accentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                if selected {
                    AppIcon.checkCircle(true, size: 18)
                        .foregroundStyle(Color.white)
                        .padding(8)
                }
            }
            .frame(height: 72)
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// Split out to keep the parent body simple for the compiler
private struct FontOptionCard: View {
    let label: String
    let titleFont: Font
    let bodyFont: Font
    let background: Color
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
                VStack(alignment: .center, spacing: 6) {
                    Text(label)
                        .font(titleFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text(sample)
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                if selected {
                    AppIcon.checkCircle(true, size: 18)
                        .foregroundStyle(Color.accentColor)
                        .padding(8)
                }
            }
            .frame(height: 92)
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }

    private var sample: String { "Aa • Readable preview" }
}

#Preview {
    do {
        let container = try ModelContainer(for: Schema([Chat.self, Message.self, AppSettings.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = SettingsStore(context: container.mainContext)
        return AnyView(
            SettingsView()
                .environment(store)
                .modelContainer(container)
        )
    } catch {
        return AnyView(Text("Preview unavailable: \(String(describing: error))"))
    }
}
