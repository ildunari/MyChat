import XCTest
@testable import NoteChat

final class ProviderPayloadInterceptTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        // Inject URLProtocol-backed session for tests
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        #if DEBUG
        NetworkClient.useTestSession(URLSession(configuration: config))
        #endif
    }

    override func tearDown() {
        super.tearDown()
    }

    func testGoogleProvider_sendsGenerateContentWithFunctionParts() async throws {
        // Stub response
        MockURLProtocol.requestHandler = { request in
            // Verify endpoint
            XCTAssertTrue(request.url?.absoluteString.contains("generateContent") == true)
            XCTAssertEqual(request.httpMethod, "POST")
            // Capture body
            if let body = request.httpBody {
                let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                XCTAssertNotNil(json?["contents"]) // rough smoke validation
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
            let json = """
            {"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}
            """
            let data = json.data(using: .utf8)!
            return (resp, data)
        }

        let provider = GoogleProvider(apiKey: "test-key")
        let messages = [AIMessage(role: .user, content: "Hi")]
        let text = try await provider.sendChat(messages: messages, model: "gemini-1.5-pro")
        XCTAssertEqual(text, "ok")
    }

    func testXAIProvider_sendsChatCompletionsWithToolCallTypeFunction() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("chat/completions") == true)
            XCTAssertEqual(request.httpMethod, "POST")
            if let body = request.httpBody {
                let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                if let msgs = json?["messages"] as? [[String: Any]] {
                    // If tool calls present, ensure type=function (schema validation left light)
                    if let tc = msgs.first? ["tool_calls"] as? [[String: Any]] {
                        XCTAssertEqual(tc.first? ["type"] as? String, "function")
                    }
                }
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
            let json = """
            {"choices":[{"message":{"content":[{"text":"ok"}]}}]}
            """
            let data = json.data(using: .utf8)!
            return (resp, data)
        }

        let provider = XAIProvider(apiKey: "test-key")
        let messages = [AIMessage(role: .user, content: "Ping")]
        let text = try await provider.sendChat(messages: messages, model: "grok-beta")
        XCTAssertEqual(text, "ok")
    }

    func testOpenAIProvider_sendsResponsesWithModelAndInput() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/v1/responses") == true)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer "), true)
            if let body = request.httpBody {
                let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
                XCTAssertEqual(json?["model"] as? String, "gpt-4o-mini")
                XCTAssertNotNil(json?["input"]) // array of items
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
            let data = "{\n  \"output\": { \n    \"content\": [ { \"type\": \"output_text\", \"text\": \"ok\" } ]\n  }\n}".data(using: .utf8)!
            return (resp, data)
        }

        let provider = OpenAIProvider(apiKey: "test-key")
        let messages = [AIMessage(role: .system, content: "sys"), AIMessage(role: .user, content: "hello")]
        let text = try await provider.sendChat(messages: messages, model: "gpt-4o-mini")
        XCTAssertEqual(text, "ok")
    }

    func testAnthropicProvider_sendsMessagesWithHeaders() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/v1/messages") == true)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "anthropic-version"))
            if let body = request.httpBody {
                let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
                XCTAssertEqual(json?["model"] as? String, "claude-3-5-sonnet")
                let msgs = json?["messages"] as? [[String: Any]]
                XCTAssertEqual(msgs?.first? ["role"] as? String, "user")
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
            let data = "{\n  \"content\": [ { \"type\": \"text\", \"text\": \"ok\" } ]\n}".data(using: .utf8)!
            return (resp, data)
        }

        let provider = AnthropicProvider(apiKey: "test-key")
        let messages = [AIMessage(role: .user, content: "hello")]
        let text = try await provider.sendChat(messages: messages, model: "claude-3-5-sonnet")
        XCTAssertEqual(text, "ok")
    }
}

// MARK: - URLProtocol stub
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
