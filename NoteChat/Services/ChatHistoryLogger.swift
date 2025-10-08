import Foundation

// MARK: - Chat Logging Context

struct ChatLoggingContext {
    let chatID: UUID
    let turnID: UUID?
    let providerID: String
    let modelID: String
    let chatTitle: String?
    let extraMetadata: [String: String]

    var sessionMetadata: [String: String] {
        var meta: [String: String] = [
            "provider": providerID,
            "model": modelID
        ]
        if let chatTitle, chatTitle.isEmpty == false {
            meta["chatTitle"] = chatTitle
        }
        if let turnID {
            meta["turnID"] = turnID.uuidString
        }
        if extraMetadata.isEmpty == false {
            for (key, value) in extraMetadata {
                meta[key] = value
            }
        }
        return meta
    }
}

enum ChatLoggingTaskLocal {
    @TaskLocal static var context: ChatLoggingContext?
}

// MARK: - Log Model

struct ChatHistorySessionFile: Codable {
    var chatID: UUID
    var providerID: String
    var modelID: String
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]
    var turns: [ChatHistoryTurn]
}

struct ChatHistoryTurn: Codable {
    enum Direction: String, Codable { case outgoing, incoming }
    enum Kind: String, Codable { case request, response, stream, reasoning, error, info }

    var id: UUID
    var turnID: UUID?
    var timestamp: Date
    var direction: Direction
    var kind: Kind
    var payload: String
    var metadata: [String: String]?
}

// MARK: - Logger

final class ChatHistoryLogger {
    static let shared = ChatHistoryLogger()

    private let queue = DispatchQueue(label: "ChatHistoryLogger.queue", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    private var cachedRootURL: URL?

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    enum Payload {
        case data(Data)
        case text(String)
    }

    func log(direction: ChatHistoryTurn.Direction,
             kind: ChatHistoryTurn.Kind,
             payload: Payload,
             metadata: [String: String]? = nil,
             context: ChatLoggingContext) {
        queue.async {
            do {
                try self.append(direction: direction,
                                kind: kind,
                                payload: payload,
                                metadata: metadata,
                                context: context)
            } catch {
#if DEBUG
                print("ChatHistoryLogger error: \(error.localizedDescription)")
#endif
            }
        }
    }

    func logError(_ message: String, context: ChatLoggingContext) {
        log(direction: .incoming,
            kind: .error,
            payload: .text(message),
            metadata: nil,
            context: context)
    }

    // MARK: - Internal helpers

    private func append(direction: ChatHistoryTurn.Direction,
                        kind: ChatHistoryTurn.Kind,
                        payload: Payload,
                        metadata: [String: String]?,
                        context: ChatLoggingContext) throws {
        guard let fileURL = sessionFileURL(for: context) else { return }

        var sessionFile = try loadSession(at: fileURL)
        let now = Date()

        if sessionFile == nil {
            sessionFile = ChatHistorySessionFile(chatID: context.chatID,
                                                 providerID: context.providerID,
                                                 modelID: context.modelID,
                                                 createdAt: now,
                                                 updatedAt: now,
                                                 metadata: context.sessionMetadata,
                                                 turns: [])
        }

        guard var workingSession = sessionFile else { return }
        workingSession.updatedAt = now

        let payloadString = string(from: payload)
        let turn = ChatHistoryTurn(id: UUID(),
                                   turnID: context.turnID,
                                   timestamp: now,
                                   direction: direction,
                                   kind: kind,
                                   payload: payloadString,
                                   metadata: metadata)
        workingSession.turns.append(turn)
        workingSession.metadata = context.sessionMetadata

        let data = try encoder.encode(workingSession)
        try data.write(to: fileURL, options: .atomic)
    }

    private func loadSession(at url: URL) throws -> ChatHistorySessionFile? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ChatHistorySessionFile.self, from: data)
    }

    private func sessionFileURL(for context: ChatLoggingContext) -> URL? {
        guard let root = resolveRootDirectory() else { return nil }
        let providerFolder = root.appendingPathComponent(context.providerID, isDirectory: true)
        do {
            try fileManager.createDirectory(at: providerFolder, withIntermediateDirectories: true)
        } catch {
#if DEBUG
            print("ChatHistoryLogger failed to create provider folder: \(error.localizedDescription)")
#endif
            return nil
        }
        return providerFolder.appendingPathComponent("\(context.chatID.uuidString).json", isDirectory: false)
    }

    private func resolveRootDirectory() -> URL? {
        if let cachedRootURL {
            return cachedRootURL
        }

        if let envRoot = ProcessInfo.processInfo.environment["CHAT_HISTORY_ROOT"], envRoot.isEmpty == false {
            let expanded = (envRoot as NSString).expandingTildeInPath
            let candidate = URL(fileURLWithPath: expanded, isDirectory: true).appendingPathComponent("ChatHistory", isDirectory: true)
            if createDirectoryIfNeeded(at: candidate) {
                cachedRootURL = candidate
                return candidate
            }
        }

        if let configured = Bundle.main.object(forInfoDictionaryKey: "ChatHistoryRoot") as? String,
           configured.isEmpty == false {
            let expanded = (configured as NSString).expandingTildeInPath
            let candidate = URL(fileURLWithPath: expanded, isDirectory: true).appendingPathComponent("ChatHistory", isDirectory: true)
            if createDirectoryIfNeeded(at: candidate) {
                cachedRootURL = candidate
                return candidate
            }
        }

        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let fallback = documents?.appendingPathComponent("ChatHistory", isDirectory: true)
        if let fallback, createDirectoryIfNeeded(at: fallback) {
            cachedRootURL = fallback
            return fallback
        }
        return nil
    }

    private func createDirectoryIfNeeded(at url: URL) -> Bool {
        if fileManager.fileExists(atPath: url.path) { return true }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
#if DEBUG
            print("ChatHistoryLogger failed to create directory at \(url.path): \(error.localizedDescription)")
#endif
            return false
        }
    }

    private func string(from payload: Payload) -> String {
        switch payload {
        case .text(let string):
            return string
        case .data(let data):
            if data.isEmpty { return "" }
            if let object = try? JSONSerialization.jsonObject(with: data, options: []),
               JSONSerialization.isValidJSONObject(object),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
                return String(data: pretty, encoding: .utf8) ?? (object as? NSDictionary)?.description ?? "<binary>"
            }
            return String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        }
    }
}

// MARK: - Convenience API

enum ChatHistoryLogging {
    static func beginTurn(metadata: [String: String]? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        var info: [String: String] = ["event": "turn-start"]
        if let metadata {
            for (key, value) in metadata { info[key] = value }
        }
        ChatHistoryLogger.shared.log(direction: .outgoing,
                                      kind: .info,
                                      payload: .text("Turn started"),
                                      metadata: info,
                                      context: context)
    }

    static func logEnvelope(_ envelope: LoggingEnvelope) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        do {
            let data = try JSONEncoder().encode(envelope)
            ChatHistoryLogger.shared.log(direction: .outgoing,
                                          kind: .request,
                                          payload: .data(data),
                                          metadata: ["format": "request-envelope"],
                                          context: context)
        } catch {
#if DEBUG
            print("ChatHistoryLogging failed to encode envelope: \(error.localizedDescription)")
#endif
        }
    }

    static func logRequest(body: Data, metadata: [String: String]? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.log(direction: .outgoing,
                                      kind: .request,
                                      payload: .data(body),
                                      metadata: metadata,
                                      context: context)
    }

    static func logResponse(data: Data, metadata: [String: String]? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.log(direction: .incoming,
                                      kind: .response,
                                      payload: .data(data),
                                      metadata: metadata,
                                      context: context)
    }

    static func logResponse(text: String, metadata: [String: String]? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.log(direction: .incoming,
                                      kind: .response,
                                      payload: .text(text),
                                      metadata: metadata,
                                      context: context)
    }

    static func logStreamChunk(_ text: String, event: String? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        var meta = [String: String]()
        if let event { meta["event"] = event }
        ChatHistoryLogger.shared.log(direction: .incoming,
                                      kind: .stream,
                                      payload: .text(text),
                                      metadata: meta.isEmpty ? nil : meta,
                                      context: context)
    }

    static func logReasoning(_ text: String) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.log(direction: .incoming,
                                      kind: .reasoning,
                                      payload: .text(text),
                                      metadata: nil,
                                      context: context)
    }

    static func logError(_ message: String) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.logError(message, context: context)
    }

    static func logInfo(_ message: String, metadata: [String: String]? = nil) {
        guard let context = ChatLoggingTaskLocal.context else { return }
        ChatHistoryLogger.shared.log(direction: .incoming,
                                      kind: .info,
                                      payload: .text(message),
                                      metadata: metadata,
                                      context: context)
    }
}

// MARK: - Request Envelope

struct LoggingEnvelope: Codable {
    struct Parameters: Codable {
        var temperature: Double?
        var topP: Double?
        var topK: Int?
        var maxOutputTokens: Int?
        var reasoningEffort: String?
        var verbosity: String?
    }

    struct Message: Codable {
        struct Part: Codable {
            enum Kind: String, Codable { case text, imageData, toolCall, toolResult, fileReference }
            var kind: Kind
            var value: String?
            var metadata: [String: String]?
        }

        var role: String
        var parts: [Part]
    }

    var provider: String
    var model: String
    var timestamp: Date
    var instructions: String?
    var parameters: Parameters
    var messages: [Message]
}

extension LoggingEnvelope {
    init(provider: String,
         model: String,
         instructions: String?,
         temperature: Double?,
         topP: Double?,
         topK: Int?,
         maxOutputTokens: Int?,
         reasoningEffort: String?,
         verbosity: String?,
         messages: [AIMessage]) {
        self.provider = provider
        self.model = model
        self.timestamp = Date()
        self.instructions = instructions?.isEmpty == true ? nil : instructions
        self.parameters = Parameters(temperature: temperature,
                                     topP: topP,
                                     topK: topK,
                                     maxOutputTokens: maxOutputTokens,
                                     reasoningEffort: reasoningEffort,
                                     verbosity: verbosity)
        self.messages = messages.map { message in
            Message(role: message.role.rawValue, parts: message.parts.map { part in
                switch part {
                case .text(let text):
                    return Message.Part(kind: .text, value: text, metadata: nil)
                case .imageData(let data, let mime):
                    return Message.Part(kind: .imageData,
                                        value: data.base64EncodedString(),
                                        metadata: ["mime": mime])
                case .toolCall(let id, let name, let arguments):
                    return Message.Part(kind: .toolCall,
                                        value: arguments,
                                        metadata: ["id": id ?? "", "name": name])
                case .toolResult(let id, let content):
                    return Message.Part(kind: .toolResult,
                                        value: content,
                                        metadata: ["id": id ?? ""])
                case .fileReference(let id):
                    return Message.Part(kind: .fileReference,
                                        value: id,
                                        metadata: nil)
                }
            })
        }
    }
}

