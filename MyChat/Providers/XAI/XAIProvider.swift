// Providers/XAIProvider.swift
import Foundation

struct XAIProvider: AIProviderAdvanced {
    let id = "xai"
    let displayName = "XAI Grok"

    private let client = NetworkClient.shared
    private let apiKey: String
    private let apiBase = URL(string: "https://api.x.ai/v1")!

    init(apiKey: String) { self.apiKey = apiKey }

    func listModels() async throws -> [String] {
        return try await ProviderAPIs.listModels(provider: .xai, apiKey: apiKey)
    }

    func sendChat(messages: [AIMessage], model: String) async throws -> String {
        try await sendChat(messages: messages, model: model, temperature: nil, topP: nil, topK: nil, maxOutputTokens: nil, reasoningEffort: nil, verbosity: nil)
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
            let r#type = "function"
            let function: Function
            struct Function: Encodable { let name: String; let arguments: String }
        }
        struct Msg: Encodable {
            let role: String
            let content: [Content]?
            let tool_calls: [ToolCall]?
            let tool_call_id: String?
        }
        struct Req: Encodable {
            let model: String
            let messages: [Msg]
            let temperature: Double?
            let top_p: Double?
            let max_tokens: Int?
            let stream: Bool
            let presence_penalty: Double?
            let frequency_penalty: Double?
            let stop: [String]?
        }
        struct Resp: Decodable { struct Choice: Decodable { struct Message: Decodable { let content: [OutPart]? }
                let message: Message }
            let choices: [Choice] }
        struct OutPart: Decodable { let text: String? }

        func dataURL(from data: Data, mime: String) -> String {
            "data:\(mime);base64,\(data.base64EncodedString())"
        }

        func buildMessages() -> [Msg] {
            messages.map { msg in
                var contents: [Content] = []
                var toolCalls: [ToolCall] = []
                var toolCallID: String?
                for part in msg.parts {
                    switch part {
                    case .text(let t):
                        contents.append(Content(type: "text", text: t, image_url: nil, file: nil))
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
                let role = msg.role == .tool ? "tool" : msg.role.rawValue
                return Msg(role: role,
                           content: contents.isEmpty ? nil : contents,
                           tool_calls: toolCalls.isEmpty ? nil : toolCalls,
                           tool_call_id: toolCallID)
            }
        }

        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let req = Req(model: model,
                      messages: buildMessages(),
                      temperature: temperature,
                      top_p: topP,
                      max_tokens: maxOutputTokens,
                      stream: false,
                      presence_penalty: caps?.preferredPresencePenalty,
                      frequency_penalty: caps?.preferredFrequencyPenalty,
                      stop: caps?.stopSequences)

        let url = apiBase.appendingPathComponent("chat/completions")
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlReq.httpBody = try JSONEncoder().encode(req)

        let (data, resp) = try await client.session.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let http = resp as? HTTPURLResponse
            let err = String(data: data, encoding: .utf8) ?? "Error"
            throw NSError(domain: "XAI", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let text = decoded.choices.first?.message.content?.compactMap { $0.text }.joined(separator: "\n") ?? ""
        return text
    }
}
