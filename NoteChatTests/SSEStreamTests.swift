import XCTest
@testable import NoteChat

final class SSEStreamTests: XCTestCase {

    func testParsesSimpleSSEStream() async throws {
        let url = URL(string: "https://mock.stream/test")!
        let payload1 = "event: delta\ndata: {\"text\":\"Hi\"}\n\n".data(using: .utf8)!
        let payload2 = "data: [DONE]\n\n".data(using: .utf8)!
        MockSSEURLProtocol.register(url: url, statusCode: 200, chunks: [payload1, payload2])

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSSEURLProtocol.self]
        let session = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let stream = try await SSEStream(session: session).connect(urlRequest: request)
        var iterator = stream.makeAsyncIterator()

        guard let first = try await iterator.next() else {
            XCTFail("Expected first event")
            return
        }
        switch first {
        case .message(let event, let data):
            XCTAssertEqual(event, "delta")
            XCTAssertEqual(String(data: data, encoding: .utf8), "{\"text\":\"Hi\"}")
        case .completed:
            XCTFail("Expected message event")
        }

        guard let second = try await iterator.next() else {
            XCTFail("Expected completion event")
            return
        }
        if case .completed = second {
            // ok
        } else {
            XCTFail("Expected completion event")
        }
    }
}

private final class MockSSEURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let chunks: [Data]
    }

    private static var responses: [URL: Response] = [:]
    private static let queue = DispatchQueue(label: "mock.sse.protocol")

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
        let response: Response? = MockSSEURLProtocol.queue.sync { MockSSEURLProtocol.responses[url] }
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
