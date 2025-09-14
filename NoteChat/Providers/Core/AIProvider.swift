// Providers/AIProvider.swift
import Foundation

struct AIMessage {
    enum Role: String, Codable { case system, user, assistant, tool }
    enum Part: Codable, Hashable {
        case text(String)
        case imageData(Data, mime: String)
        case toolCall(id: String?, name: String, arguments: String)
        case toolResult(id: String?, content: String)
        case fileReference(id: String)
    }
    var role: Role
    var parts: [Part]

    init(role: Role, content: String) {
        self.role = role
        self.parts = [.text(content)]
    }

    init(role: Role, parts: [Part]) {
        self.role = role
        self.parts = parts
    }
}

protocol AIProvider {
    var id: String { get }
    var displayName: String { get }
    func listModels() async throws -> [String]
    func sendChat(messages: [AIMessage], model: String) async throws -> String
}

// Optional advanced API with extra parameters supported by modern models (Responses API)
protocol AIProviderAdvanced: AIProvider {
    func sendChat(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxOutputTokens: Int?,
        reasoningEffort: String?, // e.g. minimal|medium|high
        verbosity: String?        // e.g. low|medium|high
    ) async throws -> String
}

protocol AIStreamingProvider {
    func streamChat(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxOutputTokens: Int?,
        reasoningEffort: String?,
        verbosity: String?,
        onDelta: @escaping (String) -> Void
    ) async throws -> String
}

// Optional streaming interface that also surfaces a lightweight reasoning/"thinking" stream when supported.
protocol AIStreamingProviderV2: AIStreamingProvider {
    func streamChat(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxOutputTokens: Int?,
        reasoningEffort: String?,
        verbosity: String?,
        onDelta: @escaping (String) -> Void,
        onReasoningDelta: @escaping (String) -> Void
    ) async throws -> String
}
