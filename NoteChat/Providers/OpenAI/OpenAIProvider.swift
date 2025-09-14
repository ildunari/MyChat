// Providers/OpenAIProvider.swift
import Foundation

func partString(_ parts: [AIMessage.Part]) -> String {
    var out = ""
    for p in parts { if case .text(let t) = p { out += (out.isEmpty ? t : "\n\n" + t) } }
    return out
}

private struct OAContent: Encodable {
    let type: String
    let text: String?
    let image_url: ImageURL?
    let tool_call: ToolCall?
    let tool_result: ToolResult?
    let file_reference: FileRef?

    init(text: String, role: AIMessage.Role) {
        self.type = role == .assistant ? "output_text" : "input_text"
        self.text = text
        self.image_url = nil
        self.tool_call = nil
        self.tool_result = nil
        self.file_reference = nil
    }

    init(imageDataURL: String) {
        self.type = "input_image"
        self.text = nil
        self.image_url = ImageURL(url: imageDataURL)
        self.tool_call = nil
        self.tool_result = nil
        self.file_reference = nil
    }

    init(toolCall: ToolCall) {
        self.type = "tool_call"
        self.text = nil
        self.image_url = nil
        self.tool_call = toolCall
        self.tool_result = nil
        self.file_reference = nil
    }

    init(toolResult: ToolResult) {
        self.type = "tool_result"
        self.text = nil
        self.image_url = nil
        self.tool_call = nil
        self.tool_result = toolResult
        self.file_reference = nil
    }

    init(fileReference id: String) {
        self.type = "input_file"
        self.text = nil
        self.image_url = nil
        self.tool_call = nil
        self.tool_result = nil
        self.file_reference = FileRef(id: id)
    }

    struct ImageURL: Encodable { let url: String }
    struct ToolCall: Encodable { let id: String?; let name: String; let arguments: String }
    struct ToolResult: Encodable { let id: String?; let content: String }
    struct FileRef: Encodable { let id: String }
}

private struct OAInputItem: Encodable {
    let role: String
    let content: [OAContent]
}

private func buildOpenAIInput(from messages: [AIMessage]) -> (instructions: String, input: [OAInputItem]) {
    func dataURL(from data: Data, mime: String) -> String {
        "data:\(mime);base64,\(data.base64EncodedString())"
    }
    let instructions = messages
        .filter { $0.role == .system }
        .map { partString($0.parts) }
        .joined(separator: "\n\n")
    let convo = messages.filter { $0.role != .system }
    let items: [OAInputItem] = convo.map { msg in
        var parts: [OAContent] = []
        for p in msg.parts {
            switch p {
            case .text(let t):
                parts.append(OAContent(text: t, role: msg.role))
            case .imageData(let data, let mime):
                parts.append(OAContent(imageDataURL: dataURL(from: data, mime: mime)))
            case .toolCall(let id, let name, let arguments):
                parts.append(OAContent(toolCall: .init(id: id, name: name, arguments: arguments)))
            case .toolResult(let id, let content):
                parts.append(OAContent(toolResult: .init(id: id, content: content)))
            case .fileReference(let id):
                parts.append(OAContent(fileReference: id))
            }
        }
        return OAInputItem(role: msg.role.rawValue, content: parts)
    }
    return (instructions, items)
}

struct OpenAIProvider: AIProviderAdvanced, AIStreamingProvider {
    let id = "openai"
    let displayName = "OpenAI"

    private let client = NetworkClient.shared
    private let apiBase = URL(string: "https://api.openai.com/v1")!
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func listModels() async throws -> [String] {
        // Common, valid defaults; users can override in Settings.
        return [
            "gpt-4o-mini",
            "gpt-4o",
            "o4-mini",
            "o3-mini",
            "o3"
        ]
    }

    // Backwards-compatible entry point delegates to Responses API implementation
    func sendChat(messages: [AIMessage], model: String) async throws -> String {
        try await sendChat(messages: messages, model: model, temperature: nil, topP: nil, topK: nil, maxOutputTokens: nil, reasoningEffort: nil, verbosity: nil)
    }

    // Responses API with multimodal support
    func sendChat(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxOutputTokens: Int?,
        reasoningEffort: String?,
        verbosity: String?
    ) async throws -> String {
        struct Req: Encodable {
            let model: String
            let input: [OAInputItem]
            let instructions: String?
            let temperature: Double?
            let top_p: Double?
            let top_k: Int?
            let max_output_tokens: Int?
            let reasoning: Reasoning?
            let verbosity: String?
            struct Reasoning: Encodable { let effort: String }
        }
        struct Resp: Decodable { let output: Output?; let response: Output? }
        struct Output: Decodable { let content: [OutPart]? }
        struct OutPart: Decodable { let type: String; let text: String? }
        let built = buildOpenAIInput(from: messages)
        let req = Req(model: model,
                      input: built.input,
                      instructions: built.instructions.isEmpty ? nil : built.instructions,
                      temperature: temperature,
                      top_p: topP,
                      top_k: topK,
                      max_output_tokens: maxOutputTokens,
                      reasoning: reasoningEffort.map { .init(effort: $0) },
                      verbosity: verbosity)

        let url = apiBase.appendingPathComponent("responses")
        let (data, http) = try await client.postJSON(url: url, body: req, headers: [
            "Authorization": "Bearer \(apiKey)"
        ])
        guard (200..<300).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let content = (decoded.output ?? decoded.response)?.content?.compactMap { $0.text }.joined(separator: "\n")
        guard let text = content, !text.isEmpty else {
            throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }
        return text
    }

    // Streaming via Responses SSE
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
    ) async throws -> String {
        struct Req: Encodable {
            let model: String
            let input: [OAInputItem]
            let instructions: String?
            let temperature: Double?
            let top_p: Double?
            let top_k: Int?
            let max_output_tokens: Int?
            let reasoning: Reasoning?
            let verbosity: String?
            let stream: Bool
            struct Reasoning: Encodable { let effort: String }
        }
        let built = buildOpenAIInput(from: messages)
        let reqBody = Req(model: model,
                          input: built.input,
                          instructions: built.instructions.isEmpty ? nil : built.instructions,
                          temperature: temperature,
                          top_p: topP,
                          top_k: topK,
                          max_output_tokens: maxOutputTokens,
                          reasoning: reasoningEffort.map { .init(effort: $0) },
                          verbosity: verbosity,
                          stream: true)

        var request = URLRequest(url: apiBase.appendingPathComponent("responses"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(reqBody)

        var full = ""
        var streamedError: String? = nil
        #if DEBUG
        var evtCounts: [String: Int] = [:]
        #endif
        let (bytes, response) = try await client.session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // Surface a helpful, user-facing error instead of NSURLError -1011
            let message: String
            switch http.statusCode {
            case 400: message = "OpenAI: 400 Bad Request — check model name and payload."
            case 401: message = "OpenAI: 401 Unauthorized — check API key in Settings."
            case 403: message = "OpenAI: 403 Forbidden — key lacks access to this model."
            case 404: message = "OpenAI: 404 Not Found — endpoint or resource not found."
            case 429: message = "OpenAI: 429 Rate limited — slow down or try later."
            case 500...599: message = "OpenAI: Server error (\(http.statusCode)). Try again."
            default: message = "OpenAI: HTTP \(http.statusCode)."
            }
            throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // Parse SSE per line to avoid relying on double-\n frame boundaries
        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "data: [DONE]" { break }
            guard line.hasPrefix("data:") else { continue }
            let payloadString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard !payloadString.isEmpty else { continue }
            guard let data = payloadString.data(using: .utf8) else { continue }
            if let env = try? JSONDecoder().decode(OpenAIStreamEnvelope.self, from: data) {
                #if DEBUG
                evtCounts[env.type, default: 0] += 1
                #endif
                switch env.type {
                case "response.output_text.delta", "response.delta":
                    let d = env.delta ?? ""
                    if !d.isEmpty { full += d; onDelta(d) }
                case "response.output_text":
                    let t = env.text ?? ""
                    if !t.isEmpty { full += t; onDelta(t) }
                case "response.completed":
                    break
                case "error":
                    streamedError = env.error?.message ?? "Response error"
                default:
                    break
                }
            }
        }
        if let err = streamedError, !err.isEmpty {
            throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            #if DEBUG
            let summary = evtCounts.map { "\($0.key):\($0.value)" }.joined(separator: ", ")
            Log.sseEvt("OpenAI stream finished empty. Events: [\(summary)]")
            #endif
            throw NSError(domain: "OpenAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty streamed response"]) 
        }
        return trimmed
    }

}

extension OpenAIProvider: AIStreamingProviderV2 {
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
    ) async throws -> String {
        struct Req: Encodable {
            let model: String
            let input: [OAInputItem]
            let instructions: String?
            let temperature: Double?
            let top_p: Double?
            let top_k: Int?
            let max_output_tokens: Int?
            let reasoning: Reasoning?
            let verbosity: String?
            let stream: Bool
            struct Reasoning: Encodable { let effort: String }
        }
        let built = buildOpenAIInput(from: messages)
        let reqBody = Req(model: model,
                          input: built.input,
                          instructions: built.instructions.isEmpty ? nil : built.instructions,
                          temperature: temperature,
                          top_p: topP,
                          top_k: topK,
                          max_output_tokens: maxOutputTokens,
                          reasoning: reasoningEffort.map { .init(effort: $0) },
                          verbosity: verbosity,
                          stream: true)

        var request = URLRequest(url: apiBase.appendingPathComponent("responses"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(reqBody)

        var full = ""
        var streamedError: String? = nil
        let (bytes, response) = try await client.session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI HTTP \(http.statusCode)"])
        }
        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "data: [DONE]" { break }
            guard line.hasPrefix("data:") else { continue }
            let payloadString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payloadString.data(using: .utf8) else { continue }
            if let env = try? JSONDecoder().decode(OpenAIStreamEnvelope.self, from: data) {
                switch env.type {
                case "response.output_text.delta", "response.delta":
                    let d = env.delta ?? ""
                    if !d.isEmpty { full += d; onDelta(d) }
                case "response.output_text":
                    let t = env.text ?? ""
                    if !t.isEmpty { full += t; onDelta(t) }
                // Heuristic hook for reasoning deltas if available in stream envelope
                case "response.reasoning.delta", "response.thinking.delta", "response.thought.delta":
                    if let d = env.delta, !d.isEmpty { onReasoningDelta(d) }
                case "response.reasoning":
                    if let t = env.text, !t.isEmpty { onReasoningDelta(t) }
                case "response.completed":
                    break
                case "error":
                    streamedError = env.error?.message ?? "Response error"
                default:
                    break
                }
            }
        }
        if let err = streamedError { throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: err]) }
        return full.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
