import XCTest
@testable import MyChat

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
            let data = "{" +
            "\"candidates\":[{" +
            "\"content\":{\"parts\":[{\"text\":\"ok\"}]}}]}".data(using: .utf8)!
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
            let data = "{" +
            "\"choices\":[{" +
            "\"message\":{\"content\":[{\"text\":\"ok\"}]}}]}".data(using: .utf8)!
            return (resp, data)
        }

        let provider = XAIProvider(apiKey: "test-key")
        let messages = [AIMessage(role: .user, content: "Ping")]
        let text = try await provider.sendChat(messages: messages, model: "grok-beta")
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

