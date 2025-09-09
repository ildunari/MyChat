// Providers/GoogleProvider.swift
import Foundation

struct GoogleProvider: AIProviderAdvanced {
    let id = "google"
    let displayName = "Google Gemini"

    private let client = NetworkClient.shared
    private let apiKey: String
    private let apiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    init(apiKey: String) { self.apiKey = apiKey }

    func listModels() async throws -> [String] {
        return try await ProviderAPIs.listModels(provider: .google, apiKey: apiKey)
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
        struct Part: Encodable {
            let text: String?
            let inlineData: InlineData?
            struct InlineData: Encodable { let mimeType: String; let data: String }
        }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct GenerationConfig: Encodable { let temperature: Double?; let topP: Double?; let topK: Int?; let maxOutputTokens: Int?; let stopSequences: [String]? }
        struct Safety: Encodable { let category: String; let threshold: String }
        struct SystemInstruction: Encodable { let role: String = "system"; let parts: [Part] }
        struct Req: Encodable {
            let contents: [Content]
            let systemInstruction: SystemInstruction?
            let generationConfig: GenerationConfig?
            let safetySettings: [Safety]?
        }
        struct Resp: Decodable {
            struct Candidate: Decodable { struct CContent: Decodable { struct P: Decodable { let text: String? }
                    let parts: [P]? }
                let content: CContent? }
            let candidates: [Candidate]?
        }

        // System prompt
        let systemText = messages.filter { $0.role == .system }
            .flatMap { msg in msg.parts.compactMap { if case let .text(t) = $0 { return t } else { return nil } } }
            .joined(separator: "\n\n")
        let sys = systemText.isEmpty ? nil : SystemInstruction(parts: [Part(text: systemText, inlineData: nil)])

        func parts(from p: [AIMessage.Part]) -> [Part] {
            p.map { item in
                switch item {
                case .text(let t): return Part(text: t, inlineData: nil)
                case .imageData(let data, let mime): return Part(text: nil, inlineData: .init(mimeType: mime, data: data.base64EncodedString()))
                }
            }
        }

        let contents: [Content] = messages.compactMap { m in
            switch m.role {
            case .system: return nil
            case .user: return Content(role: "user", parts: parts(from: m.parts))
            case .assistant: return Content(role: "model", parts: parts(from: m.parts))
            }
        }

        let stops = ModelCapabilitiesStore.get(provider: id, model: model)?.stopSequences
        let gen = GenerationConfig(temperature: temperature, topP: topP, topK: topK, maxOutputTokens: maxOutputTokens, stopSequences: stops)
        let safetyOff: [Safety] = ["HARM_CATEGORY_HARASSMENT",
                                    "HARM_CATEGORY_HATE_SPEECH",
                                    "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                                    "HARM_CATEGORY_DANGEROUS_CONTENT"].map { Safety(category: $0, threshold: "BLOCK_NONE") }

        let url = apiBase.appendingPathComponent("models/\(model):generateContent")
        var urlReq = URLRequest(url: URL(string: url.absoluteString + "?key=\(apiKey)")!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Inspect stored preference for safety off
        let caps = ModelCapabilitiesStore.get(provider: id, model: model)
        let disableSafety = caps?.disableSafetyFilters ?? true
        let req = Req(contents: contents,
                      systemInstruction: sys,
                      generationConfig: gen,
                      safetySettings: disableSafety ? safetyOff : nil)
        urlReq.httpBody = try JSONEncoder().encode(req)

        let (data, resp) = try await client.session.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let http = resp as? HTTPURLResponse
            let err = String(data: data, encoding: .utf8) ?? "Error"
            throw NSError(domain: "Google", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?.compactMap { $0.text }.joined(separator: "\n") ?? ""
        return text
    }
}
