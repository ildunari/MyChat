import XCTest
@testable import NoteChat

final class ProviderStreamingTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clear any model capability overrides set during tests
        ModelCapabilitiesStore.clearUser(provider: "anthropic", model: "claude-test")
        ModelCapabilitiesStore.clearUser(provider: "google", model: "gemini-test")
        ModelCapabilitiesStore.clearUser(provider: "xai", model: "grok-test")
    }

    func testAnthropicStreamingEmitsTextAndReasoning() async throws {
        let originalClient = NetworkClient.shared
        defer { NetworkClient.shared = originalClient }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestSSEURLProtocol.self]
        let session = URLSession(configuration: config)
        NetworkClient.shared = NetworkClient(session: session)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let payload = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg","type":"message"}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: content_block_start
        data: {"type":"content_block_start","index":1,"content_block":{"type":"thinking"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":1,"delta":{"type":"thinking_delta","text":"quick plan"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":1}

        event: message_stop
        data: {"type":"message_stop"}
        """
        .replacingOccurrences(of: "\n", with: "\r\n") + "\r\n"
        TestSSEURLProtocol.register(url: url, statusCode: 200, chunks: [Data(payload.utf8)])

        var info = ProviderModelInfo.fallback(id: "claude-test")
        info.anthropicThinkingEnabled = true
        info.anthropicThinkingBudget = 256
        ModelCapabilitiesStore.putUser(provider: "anthropic", model: "claude-test", info: info)

        let provider = AnthropicProvider(apiKey: "test-key")
        var reasoningUpdates: [String] = []
        let result = try await provider.streamChat(
            messages: [AIMessage(role: .user, content: "Hello?")],
            model: "claude-test",
            temperature: nil,
            topP: nil,
            topK: nil,
            maxOutputTokens: 256,
            reasoningEffort: "low",
            verbosity: nil,
            onDelta: { _ in },
            onReasoning: { reasoningUpdates.append($0) }
        )

        XCTAssertEqual(result, "Hello world")
        XCTAssertTrue(reasoningUpdates.contains { $0.contains("quick plan") })
    }

    func testGoogleStreamingEmitsThoughts() async throws {
        let originalClient = NetworkClient.shared
        defer { NetworkClient.shared = originalClient }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestSSEURLProtocol.self]
        let session = URLSession(configuration: config)
        NetworkClient.shared = NetworkClient(session: session)

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:streamGenerateContent?key=test")!
        let payload = """
        data: {"candidates":[{"content":{"parts":[{"text":"Hello "},{"text":"world"},{"text":"internal note","thought":true},{"reasoning":{"text":"summary"}}]},"finishReason":"STOP"}]}

        """
        TestSSEURLProtocol.register(url: url, statusCode: 200, chunks: [Data(payload.utf8)])

        let provider = GoogleProvider(apiKey: "test")
        var collected = ""
        var reasoning = ""
        let output = try await provider.streamChat(
            messages: [AIMessage(role: .user, content: "Hi")],
            model: "gemini-test",
            temperature: nil,
            topP: nil,
            topK: nil,
            maxOutputTokens: nil,
            reasoningEffort: nil,
            verbosity: nil,
            onDelta: { collected += $0 },
            onReasoning: { reasoning = $0 }
        )

        XCTAssertEqual(output, "Hello world")
        XCTAssertTrue(reasoning.contains("internal note") || reasoning.contains("summary"))
    }

    func testXAIStreamingHandlesChunks() async throws {
        let originalClient = NetworkClient.shared
        defer { NetworkClient.shared = originalClient }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestSSEURLProtocol.self]
        let session = URLSession(configuration: config)
        NetworkClient.shared = NetworkClient(session: session)

        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        let chunk1 = "data: {\"id\":\"1\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"},\"finish_reason\":null}]}\n\n"
        let chunk2 = "data: {\"id\":\"2\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello \"},\"finish_reason\":null}]}\n\n"
        let chunk3 = "data: {\"id\":\"3\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"world\",\"reasoning\":{\"text\":\"thinking\"}},\"finish_reason\":null}]}\n\n"
        let chunk4 = "data: {\"id\":\"4\",\"object\":\"chat.completion.chunk\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
        let done = "data: [DONE]\n\n"
        TestSSEURLProtocol.register(url: url,
                                    statusCode: 200,
                                    chunks: [Data(chunk1.utf8), Data(chunk2.utf8), Data(chunk3.utf8), Data(chunk4.utf8), Data(done.utf8)])

        let provider = XAIProvider(apiKey: "test")
        var collected = ""
        var reasoning = ""
        let output = try await provider.streamChat(
            messages: [AIMessage(role: .user, content: "Hi")],
            model: "grok-test",
            temperature: nil,
            topP: nil,
            topK: nil,
            maxOutputTokens: nil,
            reasoningEffort: nil,
            verbosity: nil,
            onDelta: { collected += $0 },
            onReasoning: { reasoning = $0 }
        )

        XCTAssertEqual(output, "Hello world")
        XCTAssertTrue(reasoning.contains("thinking"))
    }
}

private final class TestSSEURLProtocol: URLProtocol {
    struct Response { let statusCode: Int; let chunks: [Data] }
    private static var responses: [URL: Response] = [:]
    private static let queue = DispatchQueue(label: "test.sse.protocol")

    static func register(url: URL, statusCode: Int, chunks: [Data]) {
        queue.sync {
            responses[url] = Response(statusCode: statusCode, chunks: chunks)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        let response = TestSSEURLProtocol.queue.sync { TestSSEURLProtocol.responses[url] }
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let headers = ["Content-Type": "text/event-stream"]
        let http = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        for chunk in response.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
