import XCTest
@testable import MyChat

private final class MockImageProvider: ImageProvider {
    let id = "mock"
    let displayName = "Mock Provider"
    func listModels() async throws -> [String] { ["mock-model"] }
    func generateImage(prompt: String, model: String) async throws -> Data { Data([0x00, 0x01]) }
}

final class ImageAttachmentTests: XCTestCase {
    func testGenerateImageReturnsData() async throws {
        let provider = MockImageProvider()
        let data = try await provider.generateImage(prompt: "hi", model: "mock-model")
        XCTAssertFalse(data.isEmpty)
    }
}
