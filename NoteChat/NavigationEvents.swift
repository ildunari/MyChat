import Foundation

enum AppNavEvent {
    static let openChat = Notification.Name("AppNavOpenChat")

    static func openChat(id: UUID) {
        NotificationCenter.default.post(name: openChat, object: nil, userInfo: ["id": id])
    }
}

