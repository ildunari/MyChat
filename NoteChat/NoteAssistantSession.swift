import Foundation
import SwiftData
import Combine

@MainActor
final class NoteAssistantSession: ObservableObject {
    enum MessageRole: Hashable {
        case user(String)
        case assistant(String)
        case tool(String)
        case system(String)
    }

    @Published private(set) var messages: [MessageRole] = []
    @Published private(set) var pendingPreviews: [NoteAIToolchain.ActionPreview] = []
    @Published var streamingThought: String?
    @Published private(set) var lastError: String?

    private let settingsStore: SettingsStore
    private let toolchain: NoteAIToolchain
    private let note: Note

    var currentNote: Note { note }

    init(note: Note, settings: SettingsStore, toolchain: NoteAIToolchain) {
        self.note = note
        self.settingsStore = settings
        self.toolchain = toolchain
    }

    func send(prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        pendingPreviews.removeAll()
        streamingThought = nil
        lastError = nil
        messages.append(.user(trimmed))

        do {
            let response = try await callModel(prompt: trimmed)

            if let thought = response.thought, thought.isEmpty == false {
                messages.append(.assistant(thought))
            }

            var workingContent = note.content
            var generatedReply = false

            for action in response.actions {
                guard let name = NoteToolName(rawValue: action.tool) else {
                    messages.append(.assistant("Unknown tool: \(action.tool)"))
                    continue
                }
                let payload = action.arguments ?? NoteToolPayload()
                if NoteAIToolchain.ActionPreview.mutatingTools.contains(name) {
                    do {
                        let preview = try toolchain.previewAction(for: note,
                                                                  currentContent: workingContent,
                                                                  name: name,
                                                                  payload: payload)
                        workingContent = preview.updatedContent
                        pendingPreviews.append(preview)
                    } catch {
                        let message = "Failed to prepare \(name.rawValue): \(error.localizedDescription)"
                        messages.append(.assistant(message))
                        lastError = message
                    }
                } else {
                    do {
                        let result = try toolchain.executeReadOnly(for: note, name: name, payload: payload)
                        messages.append(.tool("\(name.rawValue): \(result.message)"))
                    } catch {
                        let message = "Failed to execute \(name.rawValue): \(error.localizedDescription)"
                        messages.append(.assistant(message))
                        lastError = message
                    }
                }
            }

            if let reply = response.reply, reply.isEmpty == false {
                messages.append(.assistant(reply))
                generatedReply = true
            }

            if pendingPreviews.isEmpty && generatedReply == false && response.actions.isEmpty {
                messages.append(.assistant("No changes suggested."))
            }
        } catch NoteAssistantError.malformedJSON(let body) {
            let snippet = body.count > 800 ? String(body.prefix(800)) + "…" : body
            let message = "Assistant returned malformed JSON. Review response manually:\n\(snippet)"
            messages.append(.assistant(message))
            lastError = message
        } catch {
            let message = "Assistant error: \(error.localizedDescription)"
            messages.append(.assistant(message))
            lastError = message
        }
    }

    func apply(preview: NoteAIToolchain.ActionPreview) {
        do {
            let result = try toolchain.applyAction(preview, to: note)
            pendingPreviews.removeAll { $0.id == preview.id }
            messages.append(.tool("Applied: \(result.message)"))
        } catch {
            let message = "Failed to apply action: \(error.localizedDescription)"
            messages.append(.assistant(message))
            lastError = message
        }
    }

    func applyAllPreviews() {
        let previews = pendingPreviews
        for preview in previews {
            apply(preview: preview)
        }
    }

    func discard(preview: NoteAIToolchain.ActionPreview) {
        pendingPreviews.removeAll { $0.id == preview.id }
        messages.append(.assistant("Discarded \(preview.name.rawValue)."))
    }

    private enum NoteAssistantError: Error {
        case malformedJSON(String)
    }

    private func callModel(prompt: String) async throws -> NoteAssistantModelResponse {
        let providerID = settingsStore.defaultProvider
        let model = settingsStore.defaultModel
        let provider = try makeProvider(id: providerID)

        let contextExcerpt = note.content.prefix(5000)
        let systemPrompt = """
        You are NoteAI, an assistant that edits a user's markdown note.
        For every response, return JSON with keys: "thought" (string), "actions" (array), "reply" (string).
        Each action must include "tool" (one of \(NoteToolName.allCases.map { $0.rawValue }.joined(separator: ", "))) and "arguments" (object with fields range/location/text as needed).
        Ranges use UTF-16 offsets. Do not wrap the JSON in markdown fences.
        """
        var messages: [AIMessage] = []
        messages.append(AIMessage(role: .system, content: systemPrompt))
        messages.append(AIMessage(role: .user,
                                  content: "Current note excerpt:\n\(contextExcerpt)\n\nUser request: \(prompt)"))

        let loggingEnabled = settingsStore.logChatTranscripts
        let loggingContext = ChatLoggingContext(chatID: note.id,
                                                turnID: nil,
                                                providerID: providerID,
                                                modelID: model,
                                                chatTitle: note.title,
                                                extraMetadata: ["flow": "noteAssistant"])

        if loggingEnabled {
            let envelope = LoggingEnvelope(provider: providerID,
                                           model: model,
                                           instructions: systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                                           temperature: nil,
                                           topP: nil,
                                           topK: nil,
                                           maxOutputTokens: nil,
                                           reasoningEffort: nil,
                                           verbosity: nil,
                                           messages: messages)
            ChatHistoryLogging.logEnvelope(envelope)
        }

        let performChat: () async throws -> String = { [self] in
            if let streaming = provider as? AIStreamingProvider {
                var buffer = ""
                streamingThought = ""
                let response = try await streaming.streamChat(
                    messages: messages,
                    model: model,
                    temperature: nil,
                    topP: nil,
                    topK: nil,
                    maxOutputTokens: nil,
                    reasoningEffort: nil,
                    verbosity: nil
                ) { delta in
                    Task { @MainActor in
                        buffer += delta
                        if (self.streamingThought?.isEmpty ?? true) {
                            self.streamingThought = buffer
                        }
                    }
                    if loggingEnabled {
                        ChatHistoryLogging.logStreamChunk(delta, event: "note-delta")
                    }
                } onReasoning: { summary in
                    Task { @MainActor in
                        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty == false {
                            self.streamingThought = trimmed
                        }
                    }
                    if loggingEnabled {
                        ChatHistoryLogging.logReasoning(summary)
                    }
                }
                streamingThought = nil
                return response
            } else if let advanced = provider as? AIProviderAdvanced {
                return try await advanced.sendChat(messages: messages,
                                                   model: model,
                                                   temperature: nil,
                                                   topP: nil,
                                                   topK: nil,
                                                   maxOutputTokens: nil,
                                                   reasoningEffort: nil,
                                                   verbosity: nil)
            } else {
                return try await provider.sendChat(messages: messages, model: model)
            }
        }

        let reply: String
        if loggingEnabled {
            reply = try await ChatLoggingTaskLocal.$context.withValue(loggingContext) {
                ChatHistoryLogging.beginTurn(metadata: [
                    "prompt": prompt,
                    "noteID": note.id.uuidString
                ])
                do {
                    let response = try await performChat()
                    ChatHistoryLogging.logResponse(text: response)
                    return response
                } catch {
                    ChatHistoryLogging.logError((error as NSError).localizedDescription)
                    throw error
                }
            }
        } else {
            reply = try await performChat()
        }

        guard let jsonText = extractJSON(from: reply) else {
            if loggingEnabled {
                ChatHistoryLogger.shared.logError("Malformed JSON in note assistant response", context: loggingContext)
            }
            throw NoteAssistantError.malformedJSON(reply)
        }
        let data = Data(jsonText.utf8)
        return try JSONDecoder().decode(NoteAssistantModelResponse.self, from: data)
    }

    private func makeProvider(id: String) throws -> AIProvider {
        switch id {
        case "openai":
            let key = (try? KeychainService.read(key: "openai_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set."])
            }
            return OpenAIProvider(apiKey: key)
        case "anthropic":
            let key = (try? KeychainService.read(key: "anthropic_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key not set."])
            }
            return AnthropicProvider(apiKey: key)
        case "google":
            let key = (try? KeychainService.read(key: "google_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google API key not set."])
            }
            return GoogleProvider(apiKey: key)
        case "xai":
            let key = (try? KeychainService.read(key: "xai_api_key")) ?? ""
            guard !key.isEmpty else {
                throw NSError(domain: "Settings", code: -1, userInfo: [NSLocalizedDescriptionKey: "X.AI API key not set."])
            }
            return XAIProvider(apiKey: key)
        default:
            throw NSError(domain: "Provider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider"])
        }
    }

    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }
}

private struct NoteAssistantModelResponse: Codable {
    struct Action: Codable {
        var tool: String
        var arguments: NoteToolPayload?
    }

    var thought: String?
    var actions: [Action]
    var reply: String?
}
