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
        struct Msg: Encodable { let role: String; let content: String }
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
        struct Resp: Decodable { struct Choice: Decodable { struct Message: Decodable { let content: String }
                let message: Message }
            let choices: [Choice] }

        // Basic text-only mapping (images not yet supported in this minimal client)
        func flatten(_ parts: [AIMessage.Part]) -> String {
            parts.compactMap { p in
                if case let .text(t) = p { return t } else { return nil }
            }.joined(separator: "\n")
        }
        let mapped: [Msg] = messages.map { m in
            switch m.role {
            case .system: return Msg(role: "system", content: flatten(m.parts))
            case .user: return Msg(role: "user", content: flatten(m.parts))
            case .assistant: return Msg(role: "assistant", content: flatten(m.parts))
            }
        }

        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let req = Req(model: model,
                      messages: mapped,
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
        let text = decoded.choices.first?.message.content ?? ""
        return text
    }
}
