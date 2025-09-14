import Foundation

enum AppNavEvent {
    static let openChat = Notification.Name("AppNavOpenChat")
    static let openDrawer = Notification.Name("AppNavOpenDrawer")
    static let closeDrawer = Notification.Name("AppNavCloseDrawer")
    static let toggleDrawer = Notification.Name("AppNavToggleDrawer")

    static func openChat(id: UUID) {
        NotificationCenter.default.post(name: openChat, object: nil, userInfo: ["id": id])
    }

    static func openHistoryDrawer() {
        NotificationCenter.default.post(name: openDrawer, object: nil)
    }

    static func closeHistoryDrawer() {
        NotificationCenter.default.post(name: closeDrawer, object: nil)
    }

    static func toggleHistoryDrawer() {
        NotificationCenter.default.post(name: toggleDrawer, object: nil)
    }
}
