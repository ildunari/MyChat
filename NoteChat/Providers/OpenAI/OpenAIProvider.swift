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

    private func sanitizedParameters(for model: String,
                                     temperature: Double?,
                                     topP: Double?,
                                     topK: Int?,
                                     verbosity: String?) -> (temperature: Double?, topP: Double?, topK: Int?, verbosity: String?) {
        let lowered = model.lowercased()
        if lowered.hasPrefix("gpt-5") {
            // GPT-5 family rejects sampling controls; strip them to avoid 400 responses.
            return (nil, nil, nil, nil)
        }
        return (temperature, topP, topK, verbosity)
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
        let sanitized = sanitizedParameters(for: model,
                                            temperature: temperature,
                                            topP: topP,
                                            topK: topK,
                                            verbosity: verbosity)
        let req = Req(model: model,
                      input: built.input,
                      instructions: built.instructions.isEmpty ? nil : built.instructions,
                      temperature: sanitized.temperature,
                      top_p: sanitized.topP,
                      top_k: sanitized.topK,
                      max_output_tokens: maxOutputTokens,
                      reasoning: reasoningEffort.map { .init(effort: $0) },
                      verbosity: sanitized.verbosity)

        let url = apiBase.appendingPathComponent("responses")
        let (data, http) = try await client.postJSON(url: url, body: req, headers: [
            "Authorization": "Bearer \(apiKey)"
        ])
        if ChatLoggingTaskLocal.context != nil {
            if let encoded = try? JSONEncoder().encode(req) {
                ChatHistoryLogging.logRequest(body: encoded, metadata: ["provider": id])
            }
            ChatHistoryLogging.logResponse(data: data, metadata: ["event": "final-response"])
        }
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
        onDelta: @escaping (String) -> Void,
        onReasoning: @escaping (String) -> Void
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
        let sanitized = sanitizedParameters(for: model,
                                            temperature: temperature,
                                            topP: topP,
                                            topK: topK,
                                            verbosity: verbosity)
        let reqBody = Req(model: model,
                          input: built.input,
                          instructions: built.instructions.isEmpty ? nil : built.instructions,
                          temperature: sanitized.temperature,
                          top_p: sanitized.topP,
                          top_k: sanitized.topK,
                          max_output_tokens: maxOutputTokens,
                          reasoning: reasoningEffort.map { .init(effort: $0) },
                          verbosity: sanitized.verbosity,
                          stream: true)

        var request = URLRequest(url: apiBase.appendingPathComponent("responses"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(reqBody)

        struct BufferKey: Hashable {
            let itemId: String?
            let outputIndex: Int
            let contentIndex: Int
        }

        func intValue(_ value: Any?) -> Int? {
            if let int = value as? Int { return int }
            if let str = value as? String, let int = Int(str) { return int }
            if let double = value as? Double { return Int(double) }
            return nil
        }

        func bufferKey(from dict: [String: Any]) -> BufferKey {
            BufferKey(itemId: dict["item_id"] as? String,
                      outputIndex: intValue(dict["output_index"]) ?? 0,
                      contentIndex: intValue(dict["content_index"]) ?? 0)
        }

        var textBuffers: [BufferKey: String] = [:]
        var full = ""
        var streamedError: String? = nil
        var reasoningAccumulator = ""
        var reasoningDelivered = false
        var streamedToolContent = false
        var incompleteReason: String? = nil

        func fragments(from value: Any) -> [String]? {
            let pieces = extractTextFragments(from: value)
            return pieces.isEmpty ? nil : pieces
        }

        func updateReasoning(_ summary: String) {
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            if trimmed == reasoningAccumulator { return }
            reasoningAccumulator = trimmed
            reasoningDelivered = true
            onReasoning(trimmed)
        }

        func appendFragment(_ fragment: String, for key: BufferKey) {
            guard fragment.isEmpty == false else { return }
            textBuffers[key, default: ""] += fragment
            full += fragment
#if DEBUG
            Log.sseEvt("OpenAI delta: \(fragment)")
#endif
            onDelta(fragment)
        }

        func mergeFullText(_ text: String, for key: BufferKey) {
            let trimmedText = text
            guard trimmedText.isEmpty == false else { return }
            let existing = textBuffers[key] ?? ""
            if trimmedText.count > existing.count {
                let suffix = trimmedText.dropFirst(existing.count)
                if suffix.isEmpty == false {
                    let addition = String(suffix)
                    textBuffers[key] = trimmedText
                    full += addition
#if DEBUG
                    Log.sseEvt("OpenAI full append: \(addition)")
#endif
                    onDelta(addition)
                } else {
                    textBuffers[key] = trimmedText
                }
            } else if existing.isEmpty {
                textBuffers[key] = trimmedText
                full += trimmedText
#if DEBUG
                Log.sseEvt("OpenAI full set: \(trimmedText)")
#endif
                onDelta(trimmedText)
            } else {
                textBuffers[key] = trimmedText
            }
        }

        func processContentPart(_ part: [String: Any], baseKey: BufferKey) {
            let type = (part["type"] as? String)?.lowercased() ?? ""
            if let text = part["text"] as? String, text.isEmpty == false {
                if ["reasoning", "thinking", "thought", "analysis"].contains(type) {
                    let combined = reasoningAccumulator.isEmpty ? text : (reasoningAccumulator + " " + text)
                    updateReasoning(combined)
                } else {
                    mergeFullText(text, for: baseKey)
                }
            }

            if let reasoning = part["reasoning"] as? [String: Any],
               let summary = extractReasoningSummary(from: reasoning) {
                updateReasoning(summary)
            }

            if let annotations = part["annotations"] as? [[String: Any]] {
                for annotation in annotations {
                    if let summary = extractReasoningSummary(from: annotation) {
                        updateReasoning(summary)
                    }
                }
            }

            if let delta = part["delta"] as? [String: Any] {
                processContentPart(delta, baseKey: baseKey)
            }

            if let nestedContent = part["content"] as? [[String: Any]] {
                for (index, nested) in nestedContent.enumerated() {
                    let nestedKey = BufferKey(itemId: baseKey.itemId,
                                              outputIndex: baseKey.outputIndex,
                                              contentIndex: baseKey.contentIndex + index + 1)
                    processContentPart(nested, baseKey: nestedKey)
                }
            }

            if let toolCall = part["tool_call"] as? [String: Any],
               let arguments = toolCall["arguments"] as? String,
               arguments.isEmpty == false {
                streamedToolContent = true
                onDelta(arguments)
            }

            if let functionCall = part["function_call"] as? [String: Any],
               let arguments = functionCall["arguments"] as? String,
               arguments.isEmpty == false {
                streamedToolContent = true
                onDelta(arguments)
            }
        }

        func handleOutputItem(_ item: [String: Any], baseKey: BufferKey) {
            let itemType = (item["type"] as? String)?.lowercased() ?? ""
            let itemId = item["id"] as? String ?? baseKey.itemId
            switch itemType {
            case "message":
                if let content = item["content"] as? [[String: Any]] {
                    for (index, part) in content.enumerated() {
                        let partKey = BufferKey(itemId: itemId,
                                                outputIndex: baseKey.outputIndex,
                                                contentIndex: baseKey.contentIndex + index)
                        processContentPart(part, baseKey: partKey)
                    }
                }
            case "reasoning":
                if let summary = extractReasoningSummary(from: item) {
                    updateReasoning(summary)
                }
            case "tool_call":
                if let tool = item["tool_call"] as? [String: Any],
                   let arguments = tool["arguments"] as? String,
                   arguments.isEmpty == false {
                    streamedToolContent = true
                    onDelta(arguments)
                }
            default:
                if let content = item["content"] as? [[String: Any]] {
                    for (index, part) in content.enumerated() {
                        let partKey = BufferKey(itemId: itemId,
                                                outputIndex: baseKey.outputIndex,
                                                contentIndex: baseKey.contentIndex + index)
                        processContentPart(part, baseKey: partKey)
                    }
                }
                if let summary = extractReasoningSummary(from: item) {
                    updateReasoning(summary)
                }
            }
        }

        func handleOutputCollection(_ items: [[String: Any]]) {
            for (index, item) in items.enumerated() {
                let baseKey = BufferKey(itemId: item["id"] as? String,
                                        outputIndex: index,
                                        contentIndex: 0)
                handleOutputItem(item, baseKey: baseKey)
            }
        }

        func messageForIncomplete(reason: String) -> String {
            switch reason.lowercased() {
            case "max_output_tokens", "max_tokens":
                return "OpenAI stopped early after hitting the Max Output Tokens limit. Try increasing the limit or shortening your prompt."
            case "background" , "interrupted", "cancelled":
                return "OpenAI interrupted the stream before completion. Please retry the request."
            default:
                return "OpenAI ended the stream early (reason: \(reason))."
            }
        }

        let stream: AsyncThrowingStream<SSEStreamEvent, Error>
        do {
            stream = try await SSEStream(session: client.session).connect(urlRequest: request)
        } catch let error as NSError where error.domain == "SSEStream" {
            let message: String
            switch error.code {
            case 400: message = "OpenAI: 400 Bad Request — check model name and payload."
            case 401: message = "OpenAI: 401 Unauthorized — check API key in Settings."
            case 403: message = "OpenAI: 403 Forbidden — key lacks access to this model."
            case 404: message = "OpenAI: 404 Not Found — endpoint or resource not found."
            case 429: message = "OpenAI: 429 Rate limited — slow down or try later."
            case 500...599: message = "OpenAI: Server error (\(error.code)). Try again."
            default: message = "OpenAI: HTTP \(error.code)."
            }
            throw NSError(domain: "OpenAI", code: error.code, userInfo: [NSLocalizedDescriptionKey: message])
        } catch {
            throw error
        }
        for try await event in stream {
            switch event {
            case .message(_, let data):
                guard let payload = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
                if payload == "[DONE]" { break }
                guard let json = payload.data(using: .utf8) else { continue }
                guard let object = try? JSONSerialization.jsonObject(with: json) else { continue }

                guard let dict = object as? [String: Any], let type = dict["type"] as? String else { continue }

                if let errorDict = dict["error"] as? [String: Any],
                   let message = errorDict["message"] as? String {
                    streamedError = message
                }

                let key = bufferKey(from: dict)

                switch type {
                case "response.created", "response.in_progress":
                    continue
                case "response.output_text.delta", "response.text.delta", "response.refusal.delta":
                    if let deltaValue = dict["delta"],
                       let fragments = fragments(from: deltaValue), fragments.isEmpty == false {
                        for fragment in fragments {
                            appendFragment(fragment, for: key)
                        }
                    }
                case "response.output_text.done", "response.text.done", "response.refusal.done":
                    if let text = dict["text"] as? String {
                        mergeFullText(text, for: key)
                    }
                case "response.function_call_arguments.delta":
                    if let deltaValue = dict["delta"],
                       let fragments = fragments(from: deltaValue), fragments.isEmpty == false {
                        let addition = fragments.joined()
                        if addition.isEmpty == false {
                            streamedToolContent = true
                            textBuffers[key, default: ""] += addition
                            onDelta(addition)
                        }
                    }
                case "response.function_call_arguments.done":
                    if let arguments = dict["arguments"] as? String, arguments.isEmpty == false {
                        streamedToolContent = true
                        let existing = textBuffers[key] ?? ""
                        if arguments.count > existing.count {
                            let addition = arguments.dropFirst(existing.count)
                            if addition.isEmpty == false {
                                let additionString = String(addition)
                                textBuffers[key] = arguments
                                onDelta(additionString)
                            } else {
                                textBuffers[key] = arguments
                            }
                        } else if existing.isEmpty {
                            textBuffers[key] = arguments
                            onDelta(arguments)
                        } else {
                            textBuffers[key] = arguments
                        }
                    }
                case "response.output_item.added":
                    if let item = dict["item"] as? [String: Any] {
                        let baseKey = BufferKey(itemId: item["id"] as? String ?? key.itemId,
                                                outputIndex: key.outputIndex,
                                                contentIndex: key.contentIndex)
                        handleOutputItem(item, baseKey: baseKey)
                    }
                case "response.output_item.done":
                    if let item = dict["item"] as? [String: Any] {
                        let baseKey = BufferKey(itemId: item["id"] as? String ?? key.itemId,
                                                outputIndex: key.outputIndex,
                                                contentIndex: key.contentIndex)
                        handleOutputItem(item, baseKey: baseKey)
                    }
                case "response.content_part.added", "response.content_part.done":
                    let partKey = BufferKey(itemId: dict["item_id"] as? String ?? key.itemId,
                                            outputIndex: key.outputIndex,
                                            contentIndex: key.contentIndex)
                    if let part = dict["content_part"] as? [String: Any] {
                        processContentPart(part, baseKey: partKey)
                    }
                case "response.content_part.delta":
                    if let deltaDict = dict["delta"] as? [String: Any] {
                        if let text = deltaDict["text"] as? String, text.isEmpty == false {
                            appendFragment(text, for: key)
                        }
                        if let reasoning = deltaDict["reasoning"] as? [String: Any],
                           let summary = extractReasoningSummary(from: reasoning) {
                            updateReasoning(summary)
                        }
                        if let annotations = deltaDict["annotations"] as? [[String: Any]] {
                            for annotation in annotations {
                                if let summary = extractReasoningSummary(from: annotation) {
                                    updateReasoning(summary)
                                }
                            }
                        }
                        if let nested = deltaDict["content"] as? [[String: Any]] {
                            for (index, part) in nested.enumerated() {
                                let nestedKey = BufferKey(itemId: key.itemId,
                                                          outputIndex: key.outputIndex,
                                                          contentIndex: key.contentIndex + index)
                                processContentPart(part, baseKey: nestedKey)
                            }
                        }
                    } else if let deltaValue = dict["delta"],
                              let fragments = fragments(from: deltaValue), fragments.isEmpty == false {
                        for fragment in fragments {
                            appendFragment(fragment, for: key)
                        }
                    }
                case "response.reasoning.delta":
                    if let deltaValue = dict["delta"],
                       let fragments = fragments(from: deltaValue), fragments.isEmpty == false {
                        let addition = fragments.joined()
                        let combined = reasoningAccumulator.isEmpty ? addition : (reasoningAccumulator + " " + addition)
                        updateReasoning(combined)
                    }
                case "response.reasoning.done":
                    if let reasoning = dict["reasoning"] as? [String: Any],
                       let summary = extractReasoningSummary(from: reasoning) {
                        updateReasoning(summary)
                    }
                case "response.completed":
                    if let responseObj = dict["response"] as? [String: Any] {
                        if let reasoning = responseObj["reasoning"] as? [String: Any],
                           let summary = extractReasoningSummary(from: reasoning) {
                            updateReasoning(summary)
                        }
                        if let outputs = responseObj["output"] as? [[String: Any]] {
                            handleOutputCollection(outputs)
                        }
                    }
                case "response.incomplete":
                    if let responseObj = dict["response"] as? [String: Any] {
                        if let reasoning = responseObj["reasoning"] as? [String: Any],
                           let summary = extractReasoningSummary(from: reasoning) {
                            updateReasoning(summary)
                        }
                        if let outputs = responseObj["output"] as? [[String: Any]] {
                            handleOutputCollection(outputs)
                        }
                        if let details = responseObj["incomplete_details"] as? [String: Any],
                           let reason = details["reason"] as? String {
                            incompleteReason = reason
                        }
                    }
                case "response.error", "response.failed":
                    if let err = dict["error"] as? [String: Any],
                       let message = err["message"] as? String {
                        streamedError = message
                    }
                default:
#if DEBUG
                    Log.sseEvt("Unhandled OpenAI SSE event: \(type)")
#endif
                    continue
                }
            case .completed:
                break
            }
        }
        if let err = streamedError, !err.isEmpty {
            throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let trimmedText = full.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReasoning = reasoningAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
#if DEBUG
        Log.sseEvt("OpenAI final length: \(full.count)")
#endif
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
            if let reason = incompleteReason {
                let message = messageForIncomplete(reason: reason)
                throw NSError(domain: "OpenAI", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "OpenAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty streamed response"])
        }
        if trimmedReasoning.isEmpty == false, reasoningDelivered == false {
            reasoningDelivered = true
            onReasoning(trimmedReasoning)
        }
        return trimmedText
    }
}

private func extractReasoningSummary(from map: [String: Any]) -> String? {
    if let summary = map["summary"] as? [[String: Any]] {
        let parts = summary.compactMap { $0["text"] as? String }
        let combined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.isEmpty == false { return combined }
    }
    if let content = map["content"] as? [[String: Any]] {
        let parts = content.compactMap { $0["text"] as? String }
        let combined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.isEmpty == false { return combined }
    }
    if let text = map["text"] as? String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { return trimmed }
    }
    return nil
}

private func extractTextFragments(from object: Any) -> [String] {
    var results: [String] = []

    if let string = object as? String {
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            results.append(string)
        }
        return results
    }

    if let array = object as? [Any] {
        for element in array {
            results.append(contentsOf: extractTextFragments(from: element))
        }
        return results
    }

    if let dict = object as? [String: Any] {
        let candidateKeys = [
            "text", "delta", "value", "content", "output", "outputs",
            "messages", "choices", "parts", "annotations", "reasoning",
            "summary", "arguments"
        ]

        for key in candidateKeys {
            guard let nested = dict[key] else { continue }
            if let nestedString = nested as? String {
                if nestedString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    results.append(nestedString)
                }
            } else {
                results.append(contentsOf: extractTextFragments(from: nested))
            }
        }
    }

    return results
}
