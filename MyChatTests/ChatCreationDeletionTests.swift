import XCTest
import SwiftData
@testable import MyChat

final class ChatCreationDeletionTests: XCTestCase {
    func testChatLifecycle() throws {
        let container = try ModelContainer(for: Chat.self, Message.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let chat = Chat(title: "Test Chat")
        context.insert(chat)
        try context.save()
        let fetch = FetchDescriptor<Chat>()
        var chats = try context.fetch(fetch)
        XCTAssertEqual(chats.count, 1)
        context.delete(chat)
        try context.save()
        chats = try context.fetch(fetch)
        XCTAssertTrue(chats.isEmpty)
    }
}
