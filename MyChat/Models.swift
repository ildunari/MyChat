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
        interfaceFontStyle: String = "rounded",
        interfaceTextSizeIndex: Int = 2,
        chatBubbleColorID: String = "coolSlate",
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

// MARK: - Notes Models

@Model
final class NoteFolder: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Note.folder) var notes: [Note]

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), notes: [Note] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.notes = notes
    }
}

@Model
final class Note: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    // Markdown content
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var folder: NoteFolder?

    init(id: UUID = UUID(), title: String = "Untitled", content: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), folder: NoteFolder? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folder = folder
    }

    // MARK: - Editing & Metrics (for future AI tooling)

    var lineCount: Int { content.components(separatedBy: .newlines).count }
    var characterCount: Int { content.count }

    // Returns the starting UTF-16 offset for each line in the document
    func lineStartOffsetsUTF16() -> [Int] {
        var offsets: [Int] = [0]
        var running = 0
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            running += (line as Substring).utf16.count + 1 // +1 for the newline
            offsets.append(running)
        }
        // Remove the trailing offset if it equals length (past-end)
        if let last = offsets.last, last == content.utf16.count { _ = offsets.popLast() }
        return offsets
    }

    // Replace a UTF-16 range with text. Safer for interoperability with external tooling.
    func replaceUTF16Range(_ range: NSRange, with replacement: String) {
        guard let r = Range(range, in: content) else { return }
        content.replaceSubrange(r, with: replacement)
        updatedAt = Date()
    }

    // Regex replace all matches (case-insensitive by default)
    func regexReplace(pattern: String, replacement: String, options: NSRegularExpression.Options = [.caseInsensitive]) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let mutable = NSMutableString(string: content)
        let range = NSRange(location: 0, length: mutable.length)
        regex.replaceMatches(in: mutable, options: [], range: range, withTemplate: replacement)
        content = String(mutable)
        updatedAt = Date()
    }
}
