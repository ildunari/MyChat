// Providers/GoogleProvider.swift
import Foundation

struct GoogleProvider: AIProviderAdvanced, AIStreamingProvider {
    let id = "google"
    let displayName = "Google Gemini"

    private let client = NetworkClient.shared
    private let apiKey: String
    private let apiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    init(apiKey: String) { self.apiKey = apiKey }

    func listModels() async throws -> [String] {
        try await ProviderAPIs.listModels(provider: .google, apiKey: apiKey)
    }

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
        _ = verbosity
        let body = buildRequestBody(messages: messages,
                                    model: model,
                                    temperature: temperature,
                                    topP: topP,
                                    topK: topK,
                                    maxTokens: maxOutputTokens,
                                    stream: false,
                                    reasoningEffort: reasoningEffort)
        let request = try makeURLRequest(body: body,
                                         model: model,
                                         stream: false)
        let (data, response) = try await client.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let http = response as? HTTPURLResponse
            let snippet = String(data: data.prefix(600), encoding: .utf8) ?? "Error"
            throw NSError(domain: "Google", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: snippet])
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?.compactMap { $0.text }.joined(separator: "\n") ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendChat(messages: [AIMessage], model: String) async throws -> String {
        try await sendChat(messages: messages,
                           model: model,
                           temperature: nil,
                           topP: nil,
                           topK: nil,
                           maxOutputTokens: nil,
                           reasoningEffort: nil,
                           verbosity: nil)
    }

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
        onReasoning: @escaping (String) -> Void
    ) async throws -> String {
        _ = verbosity
        let body = buildRequestBody(messages: messages,
                                    model: model,
                                    temperature: temperature,
                                    topP: topP,
                                    topK: topK,
                                    maxTokens: maxOutputTokens,
                                    stream: true,
                                    reasoningEffort: reasoningEffort)
        let request = try makeURLRequest(body: body,
                                         model: model,
                                         stream: true)

        let stream: AsyncThrowingStream<SSEStreamEvent, Error>
        do {
            stream = try await SSEStream(session: client.session).connect(urlRequest: request)
        } catch let error as NSError where error.domain == "SSEStream" {
            throw NSError(domain: "Google", code: error.code, userInfo: [NSLocalizedDescriptionKey: "Gemini streaming error: HTTP \(error.code)"])
        }

        var textAccumulator = ""
        var reasoningAccumulator = ""
        var errorMessage: String?
        var finished = false
        var reasoningDelivered = false
        var streamedToolContent = false

        func appendReasoning(_ value: String) {
            guard value.isEmpty == false else { return }
            reasoningAccumulator += value
            let trimmed = reasoningAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                reasoningDelivered = true
                onReasoning(trimmed)
            }
        }

        for try await event in stream {
            if finished { break }
            switch event {
            case .message(_, let data):
                guard let payload = String(data: data, encoding: .utf8), payload.isEmpty == false else { continue }
                guard let jsonData = payload.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }

                if let error = object["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }

                if let promptFeedback = object["promptFeedback"] as? [String: Any],
                   let blockReason = promptFeedback["blockReason"] as? String,
                   blockReason.isEmpty == false {
                    errorMessage = "Gemini blocked request: \(blockReason)"
                }

                if let candidates = object["candidates"] as? [[String: Any]],
                   let candidate = candidates.first {
                    if let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        for part in parts {
                            let text = part["text"] as? String
                            let isThought = (part["thought"] as? Bool) ?? ((part["type"] as? String)?.lowercased() == "thought")
                            if let chunk = text, chunk.isEmpty == false {
                                if isThought {
                                    appendReasoning(chunk)
                                } else {
                                    textAccumulator += chunk
                                    onDelta(chunk)
                                }
                            }

                            if let reasoningDict = part["reasoning"] as? [String: Any],
                               let summary = extractReasoningSummary(from: reasoningDict) {
                                appendReasoning(summary + " ")
                            }

                            if let functionCall = part["functionCall"] as? [String: Any],
                               let args = functionCall["args"] as? String,
                               args.isEmpty == false {
                                streamedToolContent = true
                                onDelta(args)
                            }

                            if let functionResponse = part["functionResponse"] as? [String: Any],
                               let response = functionResponse["response"] as? String,
                               response.isEmpty == false {
                                streamedToolContent = true
                                onDelta(response)
                            }

                            if let functionCallSnake = part["function_call"] as? [String: Any],
                               let args = functionCallSnake["arguments"] as? String,
                               args.isEmpty == false {
                                streamedToolContent = true
                                onDelta(args)
                            }

                            if let functionResponseSnake = part["function_response"] as? [String: Any],
                               let response = functionResponseSnake["response"] as? String,
                               response.isEmpty == false {
                                streamedToolContent = true
                                onDelta(response)
                            }
                        }
                    }

                    if let finish = candidate["finishReason"] as? String,
                       finish.isEmpty == false {
                        finished = true
                    }
                }
            case .completed:
                finished = true
            }
        }

        if let errorMessage, errorMessage.isEmpty == false {
            throw NSError(domain: "Google", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let trimmedText = textAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReasoning = reasoningAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            if trimmedReasoning.isEmpty == false {
                if reasoningDelivered == false {
                    reasoningDelivered = true
                    onReasoning(trimmedReasoning)
                }
                return " "
            }
            if streamedToolContent {
                return " "
            }
            throw NSError(domain: "Google", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty streamed response"])
        }
        if trimmedReasoning.isEmpty == false, reasoningDelivered == false {
            reasoningDelivered = true
            onReasoning(trimmedReasoning)
        }
        return trimmedText
    }
}

private extension GoogleProvider {
    struct Part: Encodable {
        let text: String?
        let inlineData: InlineData?
        let functionCall: FunctionCall?
        let functionResponse: FunctionResponse?
        let fileData: FileData?

        struct InlineData: Encodable { let mimeType: String; let data: String }
        struct FunctionCall: Encodable { let name: String; let args: [String: JSONValue] }
        struct FunctionResponse: Encodable { let name: String; let response: [String: JSONValue] }
        struct FileData: Encodable { let fileUri: String }
    }

    enum JSONValue: Encodable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        init(_ value: Any) {
            switch value {
            case let value as String: self = .string(value)
            case let value as Double: self = .number(value)
            case let value as Int: self = .number(Double(value))
            case let value as Bool: self = .bool(value)
            case let value as [String: Any]: self = .object(value.mapValues { JSONValue($0) })
            case let value as [Any]: self = .array(value.map { JSONValue($0) })
            default: self = .null
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }
    }

    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let maxOutputTokens: Int?
        let stopSequences: [String]?
    }

    struct Safety: Encodable { let category: String; let threshold: String }

    struct SystemInstruction: Encodable {
        let role: String = "system"
        let parts: [Part]
    }

    struct RequestBody: Encodable {
        let contents: [Content]
        let systemInstruction: SystemInstruction?
        let generationConfig: GenerationConfig?
        let safetySettings: [Safety]?
        let thinkingConfig: ThinkingConfig?

        struct ThinkingConfig: Encodable {
            let includeThoughts: Bool
            let maxReasoningTokens: Int
        }
    }

    struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct CandidateContent: Decodable {
                struct CandidatePart: Decodable { let text: String? }
                let parts: [CandidatePart]?
            }
            let content: CandidateContent?
            let finishReason: String?
        }
        let candidates: [Candidate]?
    }

    func buildRequestBody(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxTokens: Int?,
        stream: Bool,
        reasoningEffort: String?
    ) -> RequestBody {
        let systemText = messages.filter { $0.role == .system }
            .flatMap { msg in
                msg.parts.compactMap { if case let .text(t) = $0 { return t } else { return nil } }
            }
            .joined(separator: "\n\n")

        func parts(from components: [AIMessage.Part]) -> [Part] {
            components.compactMap { part in
                switch part {
                case .text(let text):
                    return Part(text: text, inlineData: nil, functionCall: nil, functionResponse: nil, fileData: nil)
                case .imageData(let data, let mime):
                    return Part(text: nil,
                                inlineData: .init(mimeType: mime, data: data.base64EncodedString()),
                                functionCall: nil,
                                functionResponse: nil,
                                fileData: nil)
                case .toolCall(_, let name, let arguments):
                    let json = Data(arguments.utf8)
                    var object: [String: JSONValue] = [:]
                    if let raw = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
                        object = raw.mapValues { JSONValue($0) }
                    }
                    return Part(text: nil,
                                inlineData: nil,
                                functionCall: .init(name: name, args: object),
                                functionResponse: nil,
                                fileData: nil)
                case .toolResult(let id, let content):
                    let json = Data(content.utf8)
                    var object: [String: JSONValue] = [:]
                    if let raw = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
                        object = raw.mapValues { JSONValue($0) }
                    }
                    return Part(text: nil,
                                inlineData: nil,
                                functionCall: nil,
                                functionResponse: .init(name: id ?? "tool", response: object),
                                fileData: nil)
                case .fileReference(let id):
                    return Part(text: nil, inlineData: nil, functionCall: nil, functionResponse: nil, fileData: .init(fileUri: id))
                }
            }
        }

        let contents: [Content] = messages.compactMap { message in
            switch message.role {
            case .system:
                return nil
            case .user:
                return Content(role: "user", parts: parts(from: message.parts))
            case .assistant:
                return Content(role: "model", parts: parts(from: message.parts))
            case .tool:
                return Content(role: "function", parts: parts(from: message.parts))
            }
        }

        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let stopSequences = caps?.stopSequences
        let config = GenerationConfig(temperature: temperature,
                                      topP: topP,
                                      topK: topK,
                                      maxOutputTokens: maxTokens,
                                      stopSequences: stopSequences)

        let disableSafety = caps?.disableSafetyFilters ?? true
        let safetyOff = ["HARM_CATEGORY_HARASSMENT",
                         "HARM_CATEGORY_HATE_SPEECH",
                         "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                         "HARM_CATEGORY_DANGEROUS_CONTENT"].map { Safety(category: $0, threshold: "BLOCK_NONE") }

        let systemInstruction = systemText.isEmpty ? nil : SystemInstruction(parts: [Part(text: systemText, inlineData: nil, functionCall: nil, functionResponse: nil, fileData: nil)])

        let effectiveEffort = reasoningEffort ?? caps?.preferredReasoningEffort
        let thinkingConfig: RequestBody.ThinkingConfig?
        if let effort = effectiveEffort?.lowercased() {
            let budget: Int
            switch effort {
            case "low", "minimal": budget = 512
            case "medium": budget = 1024
            case "high": budget = 2048
            default: budget = 1024
            }
            thinkingConfig = .init(includeThoughts: true, maxReasoningTokens: budget)
        } else {
            thinkingConfig = nil
        }

        return RequestBody(contents: contents,
                            systemInstruction: systemInstruction,
                            generationConfig: config,
                            safetySettings: disableSafety ? safetyOff : nil,
                            thinkingConfig: thinkingConfig)
    }

    func makeURLRequest(body: RequestBody, model: String, stream: Bool) throws -> URLRequest {
        let endpoint = stream ? "models/\(model):streamGenerateContent" : "models/\(model):generateContent"
        let baseURL = apiBase.appendingPathComponent(endpoint)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let finalURL = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    func extractReasoningSummary(from map: [String: Any]) -> String? {
        if let text = map["text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        if let summary = map["summary"] as? [[String: Any]] {
            let joined = summary.compactMap { $0["text"] as? String }.joined(separator: " ")
            let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        if let reasoning = map["reasoning"] as? [String: Any] {
            return extractReasoningSummary(from: reasoning)
        }
        if let entries = map["entries"] as? [[String: Any]] {
            let joined = entries.compactMap { extractReasoningSummary(from: $0) }.joined(separator: " ")
            let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        return nil
    }
}
