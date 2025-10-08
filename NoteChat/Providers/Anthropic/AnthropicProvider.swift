// Providers/AnthropicProvider.swift
import Foundation

struct AnthropicProvider: AIProviderAdvanced, AIStreamingProvider {
    let id = "anthropic"
    let displayName = "Anthropic Claude"

    private let client = NetworkClient.shared
    private let apiKey: String
    private let apiBase = URL(string: "https://api.anthropic.com/v1")!

    init(apiKey: String) { self.apiKey = apiKey }

    func listModels() async throws -> [String] {
        try await ProviderAPIs.listModels(provider: .anthropic, apiKey: apiKey)
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
        let cappedMaxTokens = max(maxOutputTokens ?? 1024, 1)
        let components = buildRequestBody(
            messages: messages,
            model: model,
            temperature: temperature,
            topP: topP,
            topK: topK,
            maxTokens: cappedMaxTokens,
            reasoningEffort: reasoningEffort,
            stream: false
        )
        let request = try makeURLRequest(body: components.body,
                                         cacheFlag: components.cacheFlag,
                                         includeThinkingBeta: components.includeThinkingBeta,
                                         stream: false)

        let (data, response) = try await client.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let http = response as? HTTPURLResponse
            let snippet = String(data: data.prefix(600), encoding: .utf8) ?? "Error"
            throw NSError(domain: "Anthropic", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: snippet])
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let combined = decoded.content.compactMap { $0.text }.joined(separator: "\n")
        return combined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendChat(messages: [AIMessage], model: String) async throws -> String {
        try await sendChat(messages: messages,
                           model: model,
                           temperature: nil,
                           topP: nil,
                           topK: nil,
                           maxOutputTokens: 1024,
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
        let cappedMaxTokens = max(maxOutputTokens ?? 1024, 1)
        let components = buildRequestBody(
            messages: messages,
            model: model,
            temperature: temperature,
            topP: topP,
            topK: topK,
            maxTokens: cappedMaxTokens,
            reasoningEffort: reasoningEffort,
            stream: true
        )
        let request = try makeURLRequest(body: components.body,
                                         cacheFlag: components.cacheFlag,
                                         includeThinkingBeta: components.includeThinkingBeta,
                                         stream: true)

        let stream: AsyncThrowingStream<SSEStreamEvent, Error>
        do {
            stream = try await SSEStream(session: client.session).connect(urlRequest: request)
        } catch let error as NSError where error.domain == "SSEStream" {
            throw NSError(domain: "Anthropic", code: error.code, userInfo: [NSLocalizedDescriptionKey: "Anthropic streaming error: HTTP \(error.code)"])
        }

        var textAccumulator = ""
        var reasoningAccumulator = ""
        var blockTypes: [Int: String] = [:]
        var errorMessage: String?
        var finished = false
        var reasoningDelivered = false
        var streamedToolContent = false

        func updateReasoning(_ addition: String) {
            guard addition.isEmpty == false else { return }
            reasoningAccumulator += addition
            let trimmed = reasoningAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                reasoningDelivered = true
                onReasoning(trimmed)
            }
        }

        outer: for try await event in stream {
            if finished { break }
            switch event {
            case .message(_, let data):
                guard let payload = String(data: data, encoding: .utf8), payload.isEmpty == false else { continue }
                if payload == "[DONE]" {
                    finished = true
                    break outer
                }
                guard let jsonData = payload.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = object["type"] as? String else {
                    continue
                }

                switch type {
                case "message_start":
                    continue
                case "content_block_start":
                    if let index = object["index"] as? Int,
                       let block = object["content_block"] as? [String: Any],
                       let blockType = block["type"] as? String {
                        blockTypes[index] = blockType
                    }
                case "content_block_delta":
                    let index = object["index"] as? Int ?? 0
                    let blockType = blockTypes[index] ?? "text"
                    guard let delta = object["delta"] as? [String: Any] else { break }

                    let text = delta["text"] as? String
                    if blockType == "text" {
                        if let chunk = text, chunk.isEmpty == false {
                            textAccumulator += chunk
                            onDelta(chunk)
                        }
                    } else if blockType == "thinking" || blockType == "reasoning" {
                        if let chunk = text, chunk.isEmpty == false {
                            updateReasoning(chunk)
                        } else if let reasoning = delta["reasoning"] as? [String: Any],
                                  let summary = extractReasoningSummary(from: reasoning) {
                            updateReasoning(summary + " ")
                        } else if let thinking = delta["thinking"] as? [String: Any],
                                  let summary = extractReasoningSummary(from: thinking) {
                            updateReasoning(summary + " ")
                        }
                    } else if blockType == "tool_use" {
                        if let partial = delta["partial_json"] as? String, partial.isEmpty == false {
                            streamedToolContent = true
                            onDelta(partial)
                        }
                    } else {
                        if let chunk = text, chunk.isEmpty == false {
                            textAccumulator += chunk
                            onDelta(chunk)
                        }
                    }
                case "content_block_stop":
                    if let index = object["index"] as? Int,
                       let blockType = blockTypes[index],
                       (blockType == "thinking" || blockType == "reasoning") {
                        let trimmed = reasoningAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty == false {
                            onReasoning(trimmed)
                        }
                    }
                case "message_delta":
                    if let delta = object["delta"] as? [String: Any] {
                        if let reasoning = delta["reasoning"] as? [String: Any],
                           let summary = extractReasoningSummary(from: reasoning) {
                            updateReasoning(summary + " ")
                        } else if let thinking = delta["thinking"] as? [String: Any],
                                  let summary = extractReasoningSummary(from: thinking) {
                            updateReasoning(summary + " ")
                        }
                    }
                case "message_stop":
                    finished = true
                    break outer
                case "error":
                    if let err = object["error"] as? [String: Any],
                       let message = err["message"] as? String {
                        errorMessage = message
                    }
                default:
#if DEBUG
                    Log.sseEvt("Unhandled Anthropic SSE event: \(type)")
#endif
                    continue
                }
            case .completed:
                finished = true
                break outer
            }
        }

        if let errorMessage, errorMessage.isEmpty == false {
            throw NSError(domain: "Anthropic", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
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
            throw NSError(domain: "Anthropic", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty streamed response"])
        }
        if trimmedReasoning.isEmpty == false, reasoningDelivered == false {
            reasoningDelivered = true
            onReasoning(trimmedReasoning)
        }
        return trimmedText
    }
}

private extension AnthropicProvider {
    struct ContentBlock: Encodable {
        let type: String
        let text: String?
        let source: ImageSource?
        let cache_control: CacheControl?

        struct ImageSource: Encodable {
            let type: String = "base64"
            let media_type: String
            let data: String
        }

        struct CacheControl: Encodable { let type: String }
    }

    struct MessageItem: Encodable {
        let role: String
        let content: [ContentBlock]
    }

    struct RequestBody: Encodable {
        struct Thinking: Encodable { let type: String; let budget_tokens: Int }

        let model: String
        let messages: [MessageItem]
        let temperature: Double?
        let top_p: Double?
        let top_k: Int?
        let max_tokens: Int?
        let system: String?
        let thinking: Thinking?
        let stream: Bool?
    }

    struct ResponseBody: Decodable {
        struct OutContent: Decodable { let type: String; let text: String? }
        let content: [OutContent]
    }

    struct RequestComponents {
        let body: RequestBody
        let cacheFlag: Bool
        let includeThinkingBeta: Bool
    }

    func buildRequestBody(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxTokens: Int,
        reasoningEffort: String?,
        stream: Bool
    ) -> RequestComponents {
        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let cacheFlag = caps?.enablePromptCaching ?? false

        let systemText = messages.filter { $0.role == .system }
            .flatMap { msg in
                msg.parts.compactMap { if case let .text(t) = $0 { return t } else { return nil } }
            }
            .joined(separator: "\n\n")

        func toBlocks(_ parts: [AIMessage.Part]) -> [ContentBlock] {
            parts.compactMap { part in
                switch part {
                case .text(let text):
                    return ContentBlock(type: "text",
                                         text: text,
                                         source: nil,
                                         cache_control: cacheFlag ? .init(type: "ephemeral") : nil)
                case .imageData(let data, let mime):
                    return ContentBlock(type: "input_image",
                                         text: nil,
                                         source: .init(media_type: mime, data: data.base64EncodedString()),
                                         cache_control: nil)
                default:
                    return nil
                }
            }
        }

        let mapped: [MessageItem] = messages.compactMap { message in
            switch message.role {
            case .system:
                return nil
            case .user:
                return MessageItem(role: "user", content: toBlocks(message.parts))
            case .assistant:
                return MessageItem(role: "assistant", content: toBlocks(message.parts))
            case .tool:
                return nil
            }
        }

        var thinking: RequestBody.Thinking? = nil
        if caps?.anthropicThinkingEnabled ?? false {
            var budget = caps?.anthropicThinkingBudget ?? 0
            if budget <= 0, let effort = reasoningEffort?.lowercased() {
                switch effort {
                case "minimal", "low": budget = 512
                case "medium": budget = 1024
                case "high": budget = 2048
                default: budget = 1024
                }
            }
            if budget <= 0 { budget = 1024 }
            thinking = .init(type: "enabled", budget_tokens: budget)
        }

        let body = RequestBody(model: model,
                               messages: mapped,
                               temperature: temperature,
                               top_p: topP,
                               top_k: topK,
                               max_tokens: maxTokens,
                               system: systemText.isEmpty ? nil : systemText,
                               thinking: thinking,
                               stream: stream ? true : nil)
        return RequestComponents(body: body,
                                 cacheFlag: cacheFlag,
                                 includeThinkingBeta: thinking != nil)
    }

    func makeURLRequest(body: RequestBody,
                        cacheFlag: Bool,
                        includeThinkingBeta: Bool,
                        stream: Bool) throws -> URLRequest {
        var request = URLRequest(url: apiBase.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var betaFlags: [String] = []
        if cacheFlag { betaFlags.append("prompt-caching-2024-07-31") }
        if includeThinkingBeta { betaFlags.append("thinking-2024-07-31") }
        if betaFlags.isEmpty == false {
            request.setValue(betaFlags.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }
        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    func extractReasoningSummary(from map: [String: Any]) -> String? {
        if let summary = map["summary"] as? [[String: Any]] {
            let text = summary.compactMap { $0["text"] as? String }.joined(separator: " ")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        if let content = map["content"] as? [[String: Any]] {
            let text = content.compactMap { $0["text"] as? String }.joined(separator: " ")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        if let text = map["text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        if let reasoning = map["reasoning"] as? [String: Any] {
            return extractReasoningSummary(from: reasoning)
        }
        if let thoughts = map["thoughts"] as? [[String: Any]] {
            let text = thoughts.compactMap { extractReasoningSummary(from: $0) }.joined(separator: " ")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false { return trimmed }
        }
        return nil
    }
}
