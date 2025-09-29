// Models.swift
import Foundation
import SwiftData

@Model
final class Chat: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.chat) var messages: [Message]

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), messages: [Message] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.messages = messages
    }
}

@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    // "user" or "assistant"
    var role: String
    var content: String
    var createdAt: Date
    var chat: Chat?

    init(id: UUID = UUID(), role: String, content: String, createdAt: Date = Date(), chat: Chat? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.chat = chat
    }
}

@Model
final class AppSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    // Provider identifier, e.g., "openai"
    var defaultProvider: String
    // Model identifier for the provider
    var defaultModel: String
    // Default chat system prompt
    var defaultSystemPrompt: String
    // Sampling controls
    var defaultTemperature: Double
    var defaultMaxTokens: Int

    // Enabled models per provider (controls which appear in picker)
    var openAIEnabledModels: [String]
    var anthropicEnabledModels: [String]
    var googleEnabledModels: [String]
    var xaiEnabledModels: [String]

    // Interface preferences
    // theme: system | light | dark
    var interfaceTheme: String
    // font style: system | serif | rounded | mono
    var interfaceFontStyle: String
    // discrete text size index 0...4 (XS..XL)
    var interfaceTextSizeIndex: Int
    // chat bubble color palette id (one of predefined ids)
    var chatBubbleColorID: String
    // Prefer prompt caching when supported by the selected provider/model
    var promptCachingEnabled: Bool
    // Feature flag: use WKWebView WebCanvas for transcript rendering
    var useWebCanvas: Bool
    // Visuals: animated liquid glass background
    var useLiquidGlass: Bool
    // Visuals: liquid glass intensity (0...1)
    var liquidGlassIntensity: Double
    // UI affordances
    var showThinkingOverlay: Bool
    var usePhosphorIcons: Bool
    var showReasoningSnippets: Bool

    // Home layout preferences
    var homeSectionOrder: [String] // e.g., ["chats", "agents"]
    var homeChatsExpanded: Bool
    var homeAgentsExpanded: Bool

    // Personalization
    var userFirstName: String
    var userLastName: String
    var userUsername: String
    var aiDisplayName: String
    var personalInfo: String
    // How many previous messages to include when sending context (-1 = all)
    var defaultHistoryLimit: Int

    init(
        id: UUID = UUID(),
        defaultProvider: String = "openai",
        defaultModel: String = "gpt-4o-mini",
        defaultSystemPrompt: String = "You are a helpful AI assistant.",
        defaultTemperature: Double = 1.0,
        defaultMaxTokens: Int = 1024,
        openAIEnabledModels: [String] = ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini"],
        anthropicEnabledModels: [String] = ["claude-3-5-sonnet", "claude-3-opus", "claude-3-haiku"],
        googleEnabledModels: [String] = ["gemini-1.5-pro", "gemini-1.5-flash"],
        xaiEnabledModels: [String] = ["grok-beta"],
        interfaceTheme: String = "system",
        interfaceFontStyle: String = "rounded",
        interfaceTextSizeIndex: Int = 2,
        chatBubbleColorID: String = "coolSlate",
        promptCachingEnabled: Bool = false,
        useWebCanvas: Bool = true,
        useLiquidGlass: Bool = true,
        liquidGlassIntensity: Double = 0.22,
        homeSectionOrder: [String] = ["chats", "agents"],
        homeChatsExpanded: Bool = true,
        homeAgentsExpanded: Bool = true,
        userFirstName: String = "",
        userLastName: String = "",
        userUsername: String = "",
        aiDisplayName: String = "",
        personalInfo: String = "",
        defaultHistoryLimit: Int = -1,
        showThinkingOverlay: Bool = true,
        showReasoningSnippets: Bool = true,
        usePhosphorIcons: Bool = false
    ) {
        self.id = id
        self.defaultProvider = defaultProvider
        self.defaultModel = defaultModel
        self.defaultSystemPrompt = defaultSystemPrompt
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.openAIEnabledModels = openAIEnabledModels
        self.anthropicEnabledModels = anthropicEnabledModels
        self.googleEnabledModels = googleEnabledModels
        self.xaiEnabledModels = xaiEnabledModels
        self.interfaceTheme = interfaceTheme
        self.interfaceFontStyle = interfaceFontStyle
        self.interfaceTextSizeIndex = interfaceTextSizeIndex
        self.chatBubbleColorID = chatBubbleColorID
        self.promptCachingEnabled = promptCachingEnabled
        self.useWebCanvas = useWebCanvas
        self.useLiquidGlass = useLiquidGlass
        self.liquidGlassIntensity = min(1, max(0, liquidGlassIntensity))
        self.showThinkingOverlay = showThinkingOverlay
        self.showReasoningSnippets = showReasoningSnippets
        self.usePhosphorIcons = usePhosphorIcons
        self.homeSectionOrder = homeSectionOrder
        self.homeChatsExpanded = homeChatsExpanded
        self.homeAgentsExpanded = homeAgentsExpanded
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.userUsername = userUsername
        self.aiDisplayName = aiDisplayName
        self.personalInfo = personalInfo
        self.defaultHistoryLimit = defaultHistoryLimit
    }
}

// MARK: - Notes Models
@Model
final class NoteFolder: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    @Relationship(deleteRule: .nullify, inverse: \Note.folder) var notes: [Note]

    init(id: UUID = UUID(), name: String, colorHex: String? = nil, notes: [Note] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.notes = notes
    }
}

@Model
final class Note: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]
    var lastEditor: String
    var lastSummary: String
    var folder: NoteFolder?
    @Relationship(deleteRule: .cascade, inverse: \NoteRevision.note) var revisions: [NoteRevision]

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        tags: [String] = [],
        lastEditor: String = "user",
        lastSummary: String = "",
        folder: NoteFolder? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.tags = tags
        self.lastEditor = lastEditor
        self.lastSummary = lastSummary
        self.folder = folder
        self.revisions = []
    }
}

@Model
final class NoteRevision: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var editor: String
    var summary: String
    var appliedDiff: String
    var selectionRange: Range<Int>?
    var contentSnapshot: String
    var note: Note?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        editor: String,
        summary: String,
        appliedDiff: String,
        selectionRange: Range<Int>? = nil,
        contentSnapshot: String,
        note: Note? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.editor = editor
        self.summary = summary
        self.appliedDiff = appliedDiff
        self.selectionRange = selectionRange
        self.contentSnapshot = contentSnapshot
        self.note = note
    }
}

// MARK: - Media Models
@Model
final class MediaCanvas: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var prompt: String
    var createdAt: Date
    var updatedAt: Date
    var providerIdentifier: String
    var defaultModelIdentifier: String
    var aspectRatio: String
    @Attribute(.externalStorage) var coverImageData: Data?
    @Relationship(deleteRule: .cascade, inverse: \MediaAsset.canvas) var assets: [MediaAsset]

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerIdentifier: String = "openai",
        defaultModelIdentifier: String = "gpt-image-1",
        aspectRatio: String = "square",
        coverImageData: Data? = nil,
        assets: [MediaAsset] = []
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerIdentifier = providerIdentifier
        self.defaultModelIdentifier = defaultModelIdentifier
        self.aspectRatio = aspectRatio
        self.coverImageData = coverImageData
        self.assets = assets
    }
}

@Model
final class MediaAsset: Identifiable {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var createdAt: Date
    var variationLevel: Double
    var modelIdentifier: String
    var isFavorite: Bool
    var sourceType: String
    var aspectRatio: String
    @Relationship var canvas: MediaCanvas?
    @Attribute(.externalStorage) var imageData: Data?

    init(
        id: UUID = UUID(),
        prompt: String,
        createdAt: Date = Date(),
        variationLevel: Double = 0.0,
        modelIdentifier: String = "gpt-image-1",
        isFavorite: Bool = false,
        sourceType: String = "generated",
        aspectRatio: String = "square",
        canvas: MediaCanvas? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.createdAt = createdAt
        self.variationLevel = variationLevel
        self.modelIdentifier = modelIdentifier
        self.isFavorite = isFavorite
        self.sourceType = sourceType
        self.aspectRatio = aspectRatio
        self.canvas = canvas
        self.imageData = imageData
    }
}
