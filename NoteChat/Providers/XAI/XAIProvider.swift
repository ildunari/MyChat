// Providers/XAIProvider.swift
import Foundation

struct XAIProvider: AIProviderAdvanced, AIStreamingProvider {
    let id = "xai"
    let displayName = "XAI Grok"

    private let client = NetworkClient.shared
    private let apiKey: String
    private let apiBase = URL(string: "https://api.x.ai/v1")!

    init(apiKey: String) { self.apiKey = apiKey }

    func listModels() async throws -> [String] {
        try await ProviderAPIs.listModels(provider: .xai, apiKey: apiKey)
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
        _ = reasoningEffort
        _ = verbosity
        let body = buildRequestBody(messages: messages,
                                    model: model,
                                    temperature: temperature,
                                    topP: topP,
                                    topK: topK,
                                    maxOutputTokens: maxOutputTokens,
                                    stream: false)
        let request = try makeURLRequest(body: body, stream: false)
        let (data, response) = try await client.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let http = response as? HTTPURLResponse
            let snippet = String(data: data.prefix(600), encoding: .utf8) ?? "Error"
            throw NSError(domain: "XAI", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: snippet])
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = decoded.choices.first?.message.content?.compactMap { $0.text }.joined(separator: "\n") ?? ""
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
        _ = reasoningEffort
        _ = verbosity
        let body = buildRequestBody(messages: messages,
                                    model: model,
                                    temperature: temperature,
                                    topP: topP,
                                    topK: topK,
                                    maxOutputTokens: maxOutputTokens,
                                    stream: true)
        let request = try makeURLRequest(body: body, stream: true)

        let stream: AsyncThrowingStream<SSEStreamEvent, Error>
        do {
            stream = try await SSEStream(session: client.session).connect(urlRequest: request)
        } catch let error as NSError where error.domain == "SSEStream" {
            throw NSError(domain: "XAI", code: error.code, userInfo: [NSLocalizedDescriptionKey: "xAI streaming error: HTTP \(error.code)"])
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
                      let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }

                if let error = object["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }

                guard let objType = object["object"] as? String else { continue }
                guard objType == "chat.completion.chunk" else {
#if DEBUG
                    Log.sseEvt("Unhandled XAI SSE object: \(objType)")
#endif
                    continue
                }
                guard let choices = object["choices"] as? [[String: Any]] else { continue }

                for choice in choices {
                    if let delta = choice["delta"] as? [String: Any] {
                        if let role = delta["role"] as? String, role == "assistant" {
                            continue
                        }

                        if let contentString = delta["content"] as? String, contentString.isEmpty == false {
                            textAccumulator += contentString
                            onDelta(contentString)
                        }

                        if let contentArray = delta["content"] as? [[String: Any]] {
                            for item in contentArray {
                                if let text = item["text"] as? String, text.isEmpty == false {
                                    textAccumulator += text
                                    onDelta(text)
                                }
                                if let reasoning = item["reasoning"] as? [String: Any],
                                   let summary = extractReasoningSummary(from: reasoning) {
                                    appendReasoning(summary + " ")
                                }
                                if let annotations = item["annotations"] as? [[String: Any]] {
                                    for annotation in annotations {
                                        if let summary = extractReasoningSummary(from: annotation) {
                                            appendReasoning(summary + " ")
                                        }
                                    }
                                }
                            }
                        }

                        if let reasoning = delta["reasoning"] as? [String: Any],
                           let summary = extractReasoningSummary(from: reasoning) {
                            appendReasoning(summary + " ")
                        }

                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for call in toolCalls {
                                if let arguments = call["function"] as? [String: Any],
                                   let args = arguments["arguments"] as? String,
                                   args.isEmpty == false {
                                    streamedToolContent = true
                                    onDelta(args)
                                }
                            }
                        }
                    }

                    if let finish = choice["finish_reason"] as? String,
                       finish.isEmpty == false {
                        finished = true
                        break outer
                    }
                }
            case .completed:
                finished = true
                break outer
            }
        }

        if let errorMessage, errorMessage.isEmpty == false {
            throw NSError(domain: "XAI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
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
            throw NSError(domain: "XAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty streamed response"])
        }
        if trimmedReasoning.isEmpty == false, reasoningDelivered == false {
            reasoningDelivered = true
            onReasoning(trimmedReasoning)
        }
        return trimmedText
    }
}

private extension XAIProvider {
    struct Content: Encodable {
        let type: String
        let text: String?
        let image_url: ImageURL?
        let file: FileRef?

        struct ImageURL: Encodable { let url: String }
        struct FileRef: Encodable { let file_id: String }
    }

    struct ToolCall: Encodable {
        let id: String?
        let type = "function"
        let function: Function
        struct Function: Encodable { let name: String; let arguments: String }
    }

    struct Message: Encodable {
        let role: String
        let content: [Content]?
        let tool_calls: [ToolCall]?
        let tool_call_id: String?
    }

    struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double?
        let top_p: Double?
        let max_tokens: Int?
        let stream: Bool
        let presence_penalty: Double?
        let frequency_penalty: Double?
        let stop: [String]?
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                struct Part: Decodable { let text: String? }
                let content: [Part]?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    struct ResponsePart: Decodable { let text: String? }

    func buildRequestBody(
        messages: [AIMessage],
        model: String,
        temperature: Double?,
        topP: Double?,
        topK: Int?,
        maxOutputTokens: Int?,
        stream: Bool
    ) -> RequestBody {
        _ = topK
        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let presence = caps?.preferredPresencePenalty
        let frequency = caps?.preferredFrequencyPenalty
        let stopSequences = caps?.stopSequences
        let maxTokens = maxOutputTokens

        func dataURL(from data: Data, mime: String) -> String {
            "data:\(mime);base64,\(data.base64EncodedString())"
        }

        let mapped: [Message] = messages.map { message in
            var contents: [Content] = []
            var toolCalls: [ToolCall] = []
            var toolCallID: String?
            for part in message.parts {
                switch part {
                case .text(let text):
                    contents.append(Content(type: "text", text: text, image_url: nil, file: nil))
                case .imageData(let data, let mime):
                    contents.append(Content(type: "image_url", text: nil, image_url: .init(url: dataURL(from: data, mime: mime)), file: nil))
                case .toolCall(let id, let name, let arguments):
                    toolCalls.append(ToolCall(id: id, function: .init(name: name, arguments: arguments)))
                case .toolResult(let id, let content):
                    contents.append(Content(type: "text", text: content, image_url: nil, file: nil))
                    toolCallID = id
                case .fileReference(let id):
                    contents.append(Content(type: "input_file", text: nil, image_url: nil, file: .init(file_id: id)))
                }
            }
            let role = message.role == .tool ? "tool" : message.role.rawValue
            return Message(role: role,
                           content: contents.isEmpty ? nil : contents,
                           tool_calls: toolCalls.isEmpty ? nil : toolCalls,
                           tool_call_id: toolCallID)
        }

        return RequestBody(model: model,
                           messages: mapped,
                           temperature: temperature,
                           top_p: topP,
                           max_tokens: maxTokens,
                           stream: stream,
                           presence_penalty: presence,
                           frequency_penalty: frequency,
                           stop: stopSequences)
    }

    func makeURLRequest(body: RequestBody, stream: Bool) throws -> URLRequest {
        let url = apiBase.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
