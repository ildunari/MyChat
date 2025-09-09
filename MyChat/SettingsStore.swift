// Services/SettingsStore.swift
import Foundation
import SwiftData

@MainActor
final class SettingsStore: ObservableObject {
    @Published var defaultProvider: String
    @Published var defaultModel: String
    @Published var openAIAPIKey: String
    @Published var anthropicAPIKey: String
    @Published var googleAPIKey: String
    @Published var xaiAPIKey: String

    // Default chat controls
    @Published var systemPrompt: String
    @Published var temperature: Double
    @Published var maxTokens: Int

    // Enabled model lists per provider
    @Published var openAIEnabled: Set<String>
    @Published var anthropicEnabled: Set<String>
    @Published var googleEnabled: Set<String>
    @Published var xaiEnabled: Set<String>

    // Interface preferences
    @Published var interfaceTheme: String // system | light | dark
    @Published var interfaceFontStyle: String // system | serif | rounded | mono
    @Published var interfaceTextSizeIndex: Int // 0...4
    @Published var chatBubbleColorID: String // palette id
    @Published var promptCachingEnabled: Bool
    @Published var useWebCanvas: Bool

    private let OPENAI_KEY_KEYCHAIN = "openai_api_key"
    private let ANTHROPIC_KEY_KEYCHAIN = "anthropic_api_key"
    private let GOOGLE_KEY_KEYCHAIN = "google_api_key"
    private let XAI_KEY_KEYCHAIN = "xai_api_key"

    private let context: ModelContext
    private var settings: AppSettings

    init(context: ModelContext) {
        self.context = context

        // Fetch or create AppSettings
        let fetch = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(fetch).first {
            self.settings = existing
        } else {
            let s = AppSettings()
            context.insert(s)
            self.settings = s
            try? context.save()
        }

        // Prepare API keys using locals first (avoid touching self before full init)
        var openAIKeyLocal = (try? KeychainService.read(key: OPENAI_KEY_KEYCHAIN)) ?? ""
        var anthropicKeyLocal = (try? KeychainService.read(key: ANTHROPIC_KEY_KEYCHAIN)) ?? ""
        var googleKeyLocal = (try? KeychainService.read(key: GOOGLE_KEY_KEYCHAIN)) ?? ""
        var xaiKeyLocal = (try? KeychainService.read(key: XAI_KEY_KEYCHAIN)) ?? ""

        #if DEBUG
        // Prime from DevSecrets.env (copied to bundle in Debug) if Keychain slots are empty
        if openAIKeyLocal.isEmpty || anthropicKeyLocal.isEmpty || googleKeyLocal.isEmpty || xaiKeyLocal.isEmpty {
            let env = EnvLoader.loadFromBundle()
            func prime(_ key: String, _ storageKey: String, current: inout String) {
                if current.isEmpty, let v = env[key], v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    current = v
                    try? KeychainService.save(key: storageKey, value: v)
                }
            }
            prime("OPENAI_API_KEY", OPENAI_KEY_KEYCHAIN, current: &openAIKeyLocal)
            prime("ANTHROPIC_API_KEY", ANTHROPIC_KEY_KEYCHAIN, current: &anthropicKeyLocal)
            prime("GOOGLE_API_KEY", GOOGLE_KEY_KEYCHAIN, current: &googleKeyLocal)
            prime("XAI_API_KEY", XAI_KEY_KEYCHAIN, current: &xaiKeyLocal)
        }
        #endif

        // Now assign all @Published stored properties
        self.defaultProvider = settings.defaultProvider
        self.defaultModel = settings.defaultModel

        self.openAIAPIKey = openAIKeyLocal
        self.anthropicAPIKey = anthropicKeyLocal
        self.googleAPIKey = googleKeyLocal
        self.xaiAPIKey = xaiKeyLocal

        self.systemPrompt = settings.defaultSystemPrompt
        self.temperature = settings.defaultTemperature
        self.maxTokens = settings.defaultMaxTokens

        self.openAIEnabled = Set(settings.openAIEnabledModels)
        self.anthropicEnabled = Set(settings.anthropicEnabledModels)
        self.googleEnabled = Set(settings.googleEnabledModels)
        self.xaiEnabled = Set(settings.xaiEnabledModels)

        self.interfaceTheme = settings.interfaceTheme
        self.interfaceFontStyle = settings.interfaceFontStyle
        self.interfaceTextSizeIndex = settings.interfaceTextSizeIndex
        self.chatBubbleColorID = settings.chatBubbleColorID
        self.promptCachingEnabled = settings.promptCachingEnabled
        self.useWebCanvas = settings.useWebCanvas
    }

    func save() {
        settings.defaultProvider = defaultProvider
        settings.defaultModel = defaultModel
        settings.defaultSystemPrompt = systemPrompt
        settings.defaultTemperature = temperature
        settings.defaultMaxTokens = maxTokens
        settings.openAIEnabledModels = Array(openAIEnabled).sorted()
        settings.anthropicEnabledModels = Array(anthropicEnabled).sorted()
        settings.googleEnabledModels = Array(googleEnabled).sorted()
        settings.xaiEnabledModels = Array(xaiEnabled).sorted()
        settings.interfaceTheme = interfaceTheme
        settings.interfaceFontStyle = interfaceFontStyle
        settings.interfaceTextSizeIndex = interfaceTextSizeIndex
        settings.chatBubbleColorID = chatBubbleColorID
        settings.promptCachingEnabled = promptCachingEnabled
        settings.useWebCanvas = useWebCanvas
        try? context.save()

        saveKeychain(key: OPENAI_KEY_KEYCHAIN, value: openAIAPIKey)
        saveKeychain(key: ANTHROPIC_KEY_KEYCHAIN, value: anthropicAPIKey)
        saveKeychain(key: GOOGLE_KEY_KEYCHAIN, value: googleAPIKey)
        saveKeychain(key: XAI_KEY_KEYCHAIN, value: xaiAPIKey)
    }

    func apiKey(for provider: String) -> String? {
        switch provider {
        case "openai":
            return (try? KeychainService.read(key: OPENAI_KEY_KEYCHAIN)) ?? nil
        case "anthropic":
            return (try? KeychainService.read(key: ANTHROPIC_KEY_KEYCHAIN)) ?? nil
        case "google":
            return (try? KeychainService.read(key: GOOGLE_KEY_KEYCHAIN)) ?? nil
        case "xai":
            return (try? KeychainService.read(key: XAI_KEY_KEYCHAIN)) ?? nil
        default:
            return nil
        }
    }

    private func saveKeychain(key: String, value: String) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? KeychainService.delete(key: key)
        } else {
            try? KeychainService.save(key: key, value: value)
        }
    }
}
