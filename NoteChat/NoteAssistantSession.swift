import Foundation
import SwiftData
import Combine

final class NoteAssistantSession: ObservableObject {
    enum MessageRole { case user(String), assistant(String), tool(String) }

    @Published private(set) var messages: [MessageRole] = []
    private let settingsStore: SettingsStore
    private let toolchain: NoteAIToolchain
    private let note: Note

    var currentNote: Note { note }

    init(note: Note, settings: SettingsStore, toolchain: NoteAIToolchain) {
        self.note = note
        self.settingsStore = settings
        self.toolchain = toolchain
    }

    @MainActor
    func send(prompt: String) async {
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        messages.append(.user(prompt))
        do {
            let response = try await callModel(prompt: prompt)
            if let thought = response.thought {
                messages.append(.assistant(thought))
            }
            for action in response.actions {
                guard let name = NoteToolName(rawValue: action.tool) else {
                    messages.append(.assistant("Unknown tool: \(action.tool)"))
                    continue
                }
                let payload = action.arguments ?? NoteToolPayload(range: nil, location: nil, text: nil, style: nil, includeContent: nil)
                if let result = try? toolchain.execute(name: name, payload: payload) {
                    messages.append(.tool("\(action.tool): \(result.message)"))
                }
            }
            if let reply = response.reply {
                messages.append(.assistant(reply))
            }
        } catch {
            messages.append(.assistant("Error: \(error.localizedDescription)"))
        }
    }

    private func callModel(prompt: String) async throws -> NoteAssistantModelResponse {
        let settings = settingsStore
        let providerID = settings.defaultProvider
        let model = settings.defaultModel
        let provider = try makeProvider(id: providerID)

        let contextText = note.content.prefix(5000)
        let systemPrompt = """
        You are NoteAI, an assistant that edits a user's markdown note.
        Current note title: \(note.title)
        Current note size: \(note.content.count) characters.
        You must reply strictly in JSON with keys: thought (string), actions (array), reply (string). Each action must include a tool (string) and arguments (object). Valid tools: \(NoteToolName.allCases.map { $0.rawValue }.joined(separator: ", ")).
        Ranges are UTF-16 offsets. Do not include triple backticks.
        """
        var messages: [AIMessage] = []
        messages.append(AIMessage(role: .system, content: systemPrompt))
        messages.append(AIMessage(role: .user, content: "Current note excerpt:\n\(contextText)\n\nUser request: \(prompt)"))

        let reply = try await provider.sendChat(messages: messages, model: model)
        let json = extractJSON(from: reply) ?? reply
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(NoteAssistantModelResponse.self, from: data)
        return decoded
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
        guard let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}") else { return nil }
        let json = text[first...last]
        return String(json)
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
