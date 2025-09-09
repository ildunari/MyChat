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
        interfaceFontStyle: String = "system",
        interfaceTextSizeIndex: Int = 2,
        chatBubbleColorID: String = "terracotta",
        promptCachingEnabled: Bool = false,
        useWebCanvas: Bool = true
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
    }
}
