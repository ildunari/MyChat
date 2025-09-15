import XCTest
@testable import NoteChat

final class MyChatTests: XCTestCase {
    func testExample() {
        XCTAssertTrue(true)
    }

    // Provider payload encoding smoke tests (no network)
    func testXAIToolCallEncoding_hasTypeFunction() throws {
        struct Function: Encodable { let name: String; let arguments: String }
        struct ToolCall: Encodable { let id: String?; let type = "function"; let function: Function }
        let tc = ToolCall(id: "call_1", function: .init(name: "search", arguments: "{\"q\":\"test\"}"))
        let data = try JSONEncoder().encode(tc)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "function")
        XCTAssertNotNil((json?["function"] as? [String: Any])?["name"])
        XCTAssertNotNil((json?["function"] as? [String: Any])?["arguments"])
    }

    func testGoogleFunctionPartsEncoding_includesFunctionCallAndResponse() throws {
        enum JSONValue: Encodable { case string(String); case number(Double); case bool(Bool); case object([String: JSONValue]); case array([JSONValue]); case null
            func encode(to encoder: Encoder) throws {
                var c = encoder.singleValueContainer()
                switch self {
                case .string(let s): try c.encode(s)
                case .number(let n): try c.encode(n)
                case .bool(let b): try c.encode(b)
                case .object(let o): try c.encode(o)
                case .array(let a): try c.encode(a)
                case .null: try c.encodeNil()
                }
            }
        }
        struct Part: Encodable {
            let text: String?
            let inlineData: [String: String]?
            let functionCall: [String: JSONValue]?
            let functionResponse: [String: JSONValue]?
            let fileData: [String: String]?
        }
        let call = Part(text: nil, inlineData: nil, functionCall: [
            "name": .string("search"),
            "args": .object(["q": .string("hello")])
        ], functionResponse: nil, fileData: nil)
        let resp = Part(text: nil, inlineData: nil, functionCall: nil, functionResponse: [
            "name": .string("search"),
            "response": .object(["results": .array([.string("a"), .string("b")])])
        ], fileData: nil)
        let data = try JSONEncoder().encode([call, resp])
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(arr)
        XCTAssertNotNil(arr?.first?["functionCall"])
        XCTAssertNotNil(arr?.last?["functionResponse"])
    }
}
