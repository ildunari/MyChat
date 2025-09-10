import XCTest
@testable import MyChat

final class MessageSendingTests: XCTestCase {
    func testSendMessageAddsToChat() {
        let chat = Chat(title: "Test")
        let message = Message(role: "user", content: "Hello", chat: chat)
        chat.messages.append(message)
        XCTAssertEqual(chat.messages.count, 1)
        XCTAssertEqual(chat.messages.first?.content, "Hello")
    }
}
