// Providers/OpenAIProvider.swift
import Foundation

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
        struct InputItem: Encodable {
            let role: String
            let content: [Content]
        }
        struct Content: Encodable {
            let type: String
            let text: String?
            let image_url: ImageURL?
            init(text: String) { self.type = "input_text"; self.text = text; self.image_url = nil }
            init(imageDataURL: String) { self.type = "input_image"; self.text = nil; self.image_url = ImageURL(url: imageDataURL) }
            struct ImageURL: Encodable { let url: String }
        }
        struct Req: Encodable {
            let model: String
            let input: [InputItem]
            let temperature: Double?
            let top_p: Double?
            let max_output_tokens: Int?
            let reasoning: Reasoning?
            let verbosity: String?
            struct Reasoning: Encodable { let effort: String }
        }
        struct Resp: Decodable { let output: Output?; let response: Output? }
        struct Output: Decodable { let content: [OutPart]? }
        struct OutPart: Decodable { let type: String; let text: String? }

        func dataURL(from data: Data, mime: String) -> String {
            let b64 = data.base64EncodedString()
            return "data:\(mime);base64,\(b64)"
        }

        let inputItems: [InputItem] = messages.map { msg in
            var parts: [Content] = []
            for p in msg.parts {
                switch p {
                case .text(let t): parts.append(.init(text: t))
                case .imageData(let data, let mime): parts.append(.init(imageDataURL: dataURL(from: data, mime: mime)))
                }
            }
            return InputItem(role: msg.role.rawValue, content: parts)
        }

        let req = Req(model: model,
                      input: inputItems,
                      temperature: temperature,
                      top_p: topP,
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
        struct InputItem: Encodable { let role: String; let content: [Content] }
        struct Content: Encodable {
            let type: String
            let text: String?
            let image_url: ImageURL?
            init(text: String) { self.type = "input_text"; self.text = text; self.image_url = nil }
            init(imageDataURL: String) { self.type = "input_image"; self.text = nil; self.image_url = ImageURL(url: imageDataURL) }
            struct ImageURL: Encodable { let url: String }
        }
        struct Req: Encodable {
            let model: String
            let input: [InputItem]
            let temperature: Double?
            let top_p: Double?
            let max_output_tokens: Int?
            let reasoning: Reasoning?
            let verbosity: String?
            let stream: Bool
            struct Reasoning: Encodable { let effort: String }
        }

        func dataURL(from data: Data, mime: String) -> String { "data:\(mime);base64,\(data.base64EncodedString())" }

        let inputItems: [InputItem] = messages.map { msg in
            var parts: [Content] = []
            for p in msg.parts {
                switch p {
                case .text(let t): parts.append(.init(text: t))
                case .imageData(let data, let mime): parts.append(.init(imageDataURL: dataURL(from: data, mime: mime)))
                }
            }
            return InputItem(role: msg.role.rawValue, content: parts)
        }

        let reqBody = Req(model: model,
                          input: inputItems,
                          temperature: temperature,
                          top_p: topP,
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
