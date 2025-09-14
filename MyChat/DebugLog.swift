import Foundation
import os

#if DEBUG
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "personal.NoteChat"
    private static let general = Logger(subsystem: subsystem, category: "app")
    private static let net = Logger(subsystem: subsystem, category: "net")
    private static let sse = Logger(subsystem: subsystem, category: "sse")

    static func info(_ message: String) { general.log("\(message, privacy: .public)") }
    static func warn(_ message: String) { general.warning("\(message, privacy: .public)") }
    static func error(_ message: String) { general.error("\(message, privacy: .public)") }
    static func netReq(_ msg: String) { net.log("\(msg, privacy: .public)") }
    static func netErr(_ msg: String) { net.error("\(msg, privacy: .public)") }
    static func sseEvt(_ msg: String) { sse.log("\(msg, privacy: .public)") }
}
#endif

