// Providers/OpenAIImageProvider.swift
import Foundation

struct OpenAIImageProvider: ImageProvider {
    let id = "openai-images"
    let displayName = "OpenAI Images"

    private let client = NetworkClient.shared
    private let apiBase = URL(string: "https://api.openai.com/v1")!
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func listModels() async throws -> [String] {
        // Defaults
        return ["gpt-image-1"]
    }

    func generateImage(prompt: String, model: String) async throws -> Data {
        struct Req: Encodable {
            let model: String
            let prompt: String
            let size: String
            let response_format: String
        }
        struct Resp: Decodable {
            struct DataItem: Decodable { let b64_json: String }
            let data: [DataItem]
        }

        let url = apiBase.appendingPathComponent("images/generations")
        let body = Req(model: model, prompt: prompt, size: "1024x1024", response_format: "b64_json")
        let (data, http) = try await client.postJSON(url: url, body: body, headers: [
            "Authorization": "Bearer \(apiKey)"
        ])
        guard (200..<300).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIImages", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: err])
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        guard let first = decoded.data.first?.b64_json, let imgData = Data(base64Encoded: first) else {
            throw NSError(domain: "OpenAIImages", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data"])
        }
        return imgData
    }
}
