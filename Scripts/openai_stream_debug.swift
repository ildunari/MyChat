import Foundation

func openAIStreamDebugMain() async {
    do {
        try await run()
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

private func run() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let apiKey = env["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
          apiKey.isEmpty == false else {
        throw DebugError.missingAPIKey
    }

    var args = Array(CommandLine.arguments.dropFirst())
    var model = env["OPENAI_MODEL"] ?? "gpt-5-nano"
    var maxOutputTokens: Int? = nil

    func consumeOption(_ flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), index < args.count - 1 else { return nil }
        let value = args[index + 1]
        args.removeSubrange(index...(index + 1))
        return value
    }

    if let suppliedModel = consumeOption("--model") ?? consumeOption("-m") {
        model = suppliedModel
    }
    if let maxOutputString = consumeOption("--max-output") ?? consumeOption("-o"),
       let parsed = Int(maxOutputString) {
        maxOutputTokens = parsed
    }

    let prompt: String
    if args.isEmpty {
        prompt = env["OPENAI_PROMPT"] ?? "Hi!"
    } else {
        prompt = args.joined(separator: " ")
    }

    let request = try buildRequest(apiKey: apiKey,
                                   model: model,
                                   prompt: prompt,
                                   maxOutputTokens: maxOutputTokens)

    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 300
    sessionConfig.timeoutIntervalForResource = 300
    let session = URLSession(configuration: sessionConfig)

    let (bytes, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw DebugError.invalidHTTPResponse
    }
    guard (200..<300).contains(http.statusCode) else {
        var body = Data()
        for try await chunk in bytes {
            body.append(chunk)
        }
        let snippet = String(data: body, encoding: .utf8) ?? "<unable to decode>"
        throw DebugError.httpError(status: http.statusCode, snippet: snippet)
    }

    print("Connected. Streaming events for model \(model) ...\n")

    for try await line in bytes.lines {
        if line.hasPrefix(":") || line.isEmpty {
            continue
        }
        guard line.hasPrefix("data:") else {
            print("SSE OTHER: \(line)")
            continue
        }

        let dataPortion = line.dropFirst("data:".count).trimmingCharacters(in: CharacterSet.whitespaces)
        if dataPortion == "[DONE]" {
            print("\n[STREAM DONE]")
            break
        }

        print("RAW: \(dataPortion)")
        guard let payloadData = dataPortion.data(using: String.Encoding.utf8) else {
            continue
        }
        if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            prettyPrint(json: json)
        }
    }
}

private func buildRequest(apiKey: String,
                          model: String,
                          prompt: String,
                          maxOutputTokens: Int?) throws -> URLRequest {
    struct Content: Codable { let type: String; let text: String? }
    struct InputItem: Codable { let role: String; let content: [Content] }
    struct RequestBody: Codable {
        let model: String
        let input: [InputItem]
        let instructions: String?
        let temperature: Double?
        let top_p: Double?
        let top_k: Int?
        let max_output_tokens: Int?
        let stream: Bool
    }

    let content = Content(type: "input_text", text: prompt)
    let inputItem = InputItem(role: "user", content: [content])
    let body = RequestBody(model: model,
                           input: [inputItem],
                           instructions: nil,
                           temperature: nil,
                           top_p: nil,
                           top_k: nil,
                           max_output_tokens: maxOutputTokens,
                           stream: true)

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .useDefaultKeys
    let data = try encoder.encode(body)

    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = data
    return request
}

private func prettyPrint(json: [String: Any], indent: Int = 0) {
    let padding = String(repeating: " ", count: indent)
    if let type = json["type"] as? String {
        print("\(padding)type: \(type)")
    }
    if let response = json["response"] as? [String: Any] {
        print("\(padding)response:")
        dumpDictionary(response, indent: indent + 2)
    }
    let otherKeys = json.keys.filter { $0 != "type" && $0 != "response" }
    for key in otherKeys.sorted() {
        let value = json[key] ?? "<nil>"
        print("\(padding)\(key): \(value)")
    }
}

private func dumpDictionary(_ dict: [String: Any], indent: Int) {
    let padding = String(repeating: " ", count: indent)
    for key in dict.keys.sorted() {
        let value = dict[key] ?? "<nil>"
        if let nested = value as? [String: Any] {
            print("\(padding)\(key):")
            dumpDictionary(nested, indent: indent + 2)
        } else if let array = value as? [Any] {
            print("\(padding)\(key): [")
            dumpArray(array, indent: indent + 2)
            print("\(padding)]")
        } else {
            print("\(padding)\(key): \(value)")
        }
    }
}

private func dumpArray(_ array: [Any], indent: Int) {
    let padding = String(repeating: " ", count: indent)
    for element in array {
        if let nested = element as? [String: Any] {
            print("\(padding){")
            dumpDictionary(nested, indent: indent + 2)
            print("\(padding)}")
        } else if let nestedArray = element as? [Any] {
            print("\(padding)[")
            dumpArray(nestedArray, indent: indent + 2)
            print("\(padding)]")
        } else {
            print("\(padding)\(element)")
        }
    }
}

private enum DebugError: Error, CustomStringConvertible {
    case missingAPIKey
    case invalidHTTPResponse
    case httpError(status: Int, snippet: String)

    var description: String {
        switch self {
        case .missingAPIKey:
            return "Set OPENAI_API_KEY in the environment first."
        case .invalidHTTPResponse:
            return "Response was not HTTPURLResponse."
        case .httpError(let status, let snippet):
            return "HTTP \(status): \(snippet)"
        }
    }
}

Task {
    await openAIStreamDebugMain()
}

dispatchMain()
