// Services/SettingsStore.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsStore {
    var defaultProvider: String
    var defaultModel: String
    var openAIAPIKey: String {
        didSet { if oldValue != openAIAPIKey { hasUnsavedChanges = true } }
    }
    var anthropicAPIKey: String {
        didSet { if oldValue != anthropicAPIKey { hasUnsavedChanges = true } }
    }
    var googleAPIKey: String {
        didSet { if oldValue != googleAPIKey { hasUnsavedChanges = true } }
    }
    var xaiAPIKey: String {
        didSet { if oldValue != xaiAPIKey { hasUnsavedChanges = true } }
    }

    // Default chat controls - these need explicit save
    var systemPrompt: String {
        didSet { if oldValue != systemPrompt { hasUnsavedChanges = true } }
    }
    var temperature: Double {
        didSet { if oldValue != temperature { hasUnsavedChanges = true } }
    }
    var maxTokens: Int {
        didSet { if oldValue != maxTokens { hasUnsavedChanges = true } }
    }

    // Enabled model lists per provider
    var openAIEnabled: Set<String>
    var anthropicEnabled: Set<String>
    var googleEnabled: Set<String>
    var xaiEnabled: Set<String>

    // Interface preferences
    var interfaceTheme: String // system | light | dark
    var interfaceFontStyle: String // system | serif | rounded | mono
    var interfaceTextSizeIndex: Int // 0...4
    var chatBubbleColorID: String // palette id
    var promptCachingEnabled: Bool
    var useWebCanvas: Bool
    var enterToSend: Bool
    var preserveDrafts: Bool
    var useLiquidGlass: Bool
    var liquidGlassIntensity: Double
    var showThinkingOverlay: Bool
    var showReasoningSnippets: Bool
    var defaultHistoryLimit: Int // -1 = all, otherwise last N messages
    // Home layout prefs
    var homeSectionOrder: [String]
    var homeChatsExpanded: Bool
    var homeAgentsExpanded: Bool

    // Personalization
    var userFirstName: String
    var userLastName: String
    var userUsername: String
    var aiName: String
    var personalInfo: String {
        didSet { if oldValue != personalInfo { hasUnsavedChanges = true } }
    }
    
    // Track unsaved changes for settings that need explicit save
    var hasUnsavedChanges: Bool = false

    private let OPENAI_KEY_KEYCHAIN = "openai_api_key"
    private let ANTHROPIC_KEY_KEYCHAIN = "anthropic_api_key"
    private let GOOGLE_KEY_KEYCHAIN = "google_api_key"
    private let XAI_KEY_KEYCHAIN = "xai_api_key"

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var settings: AppSettings

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

        // Now assign all stored properties
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
        self.enterToSend = settings.enterToSend
        self.preserveDrafts = settings.preserveDrafts
        self.useLiquidGlass = settings.useLiquidGlass
        self.liquidGlassIntensity = settings.liquidGlassIntensity
        self.showThinkingOverlay = settings.showThinkingOverlay
        self.showReasoningSnippets = settings.showReasoningSnippets
        self.defaultHistoryLimit = settings.defaultHistoryLimit
        self.homeSectionOrder = settings.homeSectionOrder
        self.homeChatsExpanded = settings.homeChatsExpanded
        self.homeAgentsExpanded = settings.homeAgentsExpanded

        // Personalization
        self.userFirstName = settings.userFirstName
        self.userLastName = settings.userLastName
        self.userUsername = settings.userUsername
        self.aiName = settings.aiDisplayName
        self.personalInfo = settings.personalInfo
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
        settings.enterToSend = enterToSend
        settings.preserveDrafts = preserveDrafts
        settings.useLiquidGlass = useLiquidGlass
        settings.liquidGlassIntensity = liquidGlassIntensity
        settings.showThinkingOverlay = showThinkingOverlay
        settings.showReasoningSnippets = showReasoningSnippets
        settings.defaultHistoryLimit = defaultHistoryLimit
        settings.homeSectionOrder = homeSectionOrder
        settings.homeChatsExpanded = homeChatsExpanded
        settings.homeAgentsExpanded = homeAgentsExpanded
        settings.userFirstName = userFirstName
        settings.userLastName = userLastName
        settings.userUsername = userUsername
        settings.aiDisplayName = aiName
        settings.personalInfo = personalInfo
        try? context.save()

        saveKeychain(key: OPENAI_KEY_KEYCHAIN, value: openAIAPIKey)
        saveKeychain(key: ANTHROPIC_KEY_KEYCHAIN, value: anthropicAPIKey)
        saveKeychain(key: GOOGLE_KEY_KEYCHAIN, value: googleAPIKey)
        saveKeychain(key: XAI_KEY_KEYCHAIN, value: xaiAPIKey)
        
        // Reset the flag after saving
        hasUnsavedChanges = false
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
