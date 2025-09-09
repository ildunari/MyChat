// Services/ProviderAPIs.swift
import Foundation

enum ProviderID: String, CaseIterable {
    case openai
    case anthropic
    case google
    case xai

    var displayName: String {
        switch self {
        case .openai: return "OpenAI ChatGPT"
        case .anthropic: return "Anthropic Claude"
        case .google: return "Google Gemini"
        case .xai: return "XAI Grok"
        }
    }
}

struct ProviderAPIs {
    static let client = NetworkClient.shared

    static func listModels(provider: ProviderID, apiKey: String) async throws -> [String] {
        switch provider {
        case .openai:
            let (data, http) = try await client.get(url: URL(string: "https://api.openai.com/v1/models")!, headers: [
                "Authorization": "Bearer \(apiKey)"
            ])
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            return decoded.data.map { $0.id }.sorted()

        case .anthropic:
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
            req.httpMethod = "GET"
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let (data, resp) = try await client.session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let http = resp as? HTTPURLResponse
                throw NSError(domain: "Anthropic", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            return decoded.data.map { $0.id }.sorted()

        case .google:
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
            let (data, http) = try await client.get(url: url)
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "Google", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let name: String }
                let models: [Item]? }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            return (decoded.models ?? []).map { $0.name }

        case .xai:
            let (data, http) = try await client.get(url: URL(string: "https://api.x.ai/v1/models")!, headers: [
                "Authorization": "Bearer \(apiKey)"
            ])
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "XAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            return decoded.data.map { $0.id }.sorted()
        }
    }

    static func verifyKey(provider: ProviderID, apiKey: String) async -> Bool {
        do {
            _ = try await listModels(provider: provider, apiKey: apiKey)
            return true
        } catch {
            return false
        }
    }

    // Fetch detailed model info where the provider exposes it; otherwise return best‑effort defaults
    static func listModelInfos(provider: ProviderID, apiKey: String) async throws -> [ProviderModelInfo] {
        switch provider {
        case .google:
            // Google Generative Language API exposes token limits + temperature in the model resource
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
            let (data, http) = try await client.get(url: url)
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "Google", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable {
                struct Item: Decodable {
                    let name: String
                    let displayName: String?
                    let inputTokenLimit: Int?
                    let outputTokenLimit: Int?
                    let temperature: Double?
                    let topP: Double?
                    let topK: Int?
                    let thinking: Bool?
                }
                let models: [Item]?
            }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            let infos = (decoded.models ?? []).map { item in
                ProviderModelInfo(id: item.name,
                                  displayName: item.displayName,
                                  inputTokenLimit: item.inputTokenLimit,
                                  outputTokenLimit: item.outputTokenLimit,
                                  maxTemperature: item.temperature ?? 2.0,
                                  supportsPromptCaching: item.thinking ?? false, // treat thinking support as caching-like flag
                                  preferredTemperature: item.temperature,
                                  preferredTopP: item.topP,
                                  preferredTopK: item.topK,
                                  preferredMaxOutputTokens: item.outputTokenLimit,
                                  preferredReasoningEffort: nil,
                                  preferredVerbosity: nil,
                                  disableSafetyFilters: true)
            }
            // Update defaults layer immediately
            ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
            return infos

        case .openai:
            // OpenAI /v1/models lists models but does not currently return token limits via API.
            // Return conservative defaults; UI will still become dynamic based on these values.
            let (data, http) = try await client.get(url: URL(string: "https://api.openai.com/v1/models")!, headers: [
                "Authorization": "Bearer \(apiKey)"
            ])
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            let infos = decoded.data.map { item in
                // Heuristic defaults. Adjust as needed when OpenAI exposes richer metadata.
                ProviderModelInfo(id: item.id,
                                  displayName: nil,
                                  inputTokenLimit: nil,
                                  outputTokenLimit: 8192,
                                  maxTemperature: 2.0,
                                  supportsPromptCaching: false)
            }
            ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
            return infos

        case .anthropic:
            // Anthropic models endpoint lists IDs; public per‑model limits are documented, not returned here.
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
            req.httpMethod = "GET"
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let (data, resp) = try await client.session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let http = resp as? HTTPURLResponse
                throw NSError(domain: "Anthropic", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Error"])
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            // Conservative, well‑known defaults by common family name. Values are a best‑effort guide.
            func defaults(for id: String) -> (input: Int?, output: Int?, temp: Double, caching: Bool) {
                // Anthropic does not return limits from /v1/models; use safe, generic defaults.
                // Values here are conservative placeholders for UI bounds only.
                return (input: nil, output: 8_192, temp: 2.0, caching: true)
            }
            let infos = decoded.data.map { item in
                let d = defaults(for: item.id)
                return ProviderModelInfo(id: item.id,
                                         displayName: nil,
                                         inputTokenLimit: d.input,
                                         outputTokenLimit: d.output,
                                         maxTemperature: d.temp,
                                         supportsPromptCaching: d.caching)
            }
            ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
            return infos

        case .xai:
            // xAI currently documents models and limits; model listing endpoint may vary by account.
            // Fallback to the generic list and provide broadly safe defaults.
            let (data, http) = try await client.get(url: URL(string: "https://api.x.ai/v1/models")!, headers: [
                "Authorization": "Bearer \(apiKey)"
            ])
            guard (200..<300).contains(http.statusCode) else {
                // if listing fails, synthesize common IDs to seed UI
                let common = ["grok-3-mini", "grok-3-mini-high", "grok-2", "grok-beta"]
                return common.map { ProviderModelInfo(id: $0, displayName: nil, inputTokenLimit: 131_072, outputTokenLimit: 8_192, maxTemperature: 2.0, supportsPromptCaching: true) }
            }
            struct ModelList: Decodable { struct Item: Decodable { let id: String }
                let data: [Item] }
            let decoded = try JSONDecoder().decode(ModelList.self, from: data)
            let infos = decoded.data.map { item in
                ProviderModelInfo(id: item.id, displayName: nil, inputTokenLimit: 131_072, outputTokenLimit: 8_192, maxTemperature: 2.0, supportsPromptCaching: true)
            }
            ModelCapabilitiesStore.putDefault(provider: provider.rawValue, infos: infos)
            return infos
        }
    }
}
