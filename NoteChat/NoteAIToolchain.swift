import Foundation
import SwiftData

enum NoteToolName: String, CaseIterable {
    case readNote = "read_note"
    case readSelection = "read_selection"
    case replaceRange = "replace_range"
    case insertText = "insert_text"
    case deleteRange = "delete_range"
    case replaceAll = "replace_all"
    case outline = "outline"
    case metadata = "metadata"
}

struct NoteToolDefinition: Identifiable {
    let id: NoteToolName
    let displayName: String
    let description: String
    let requiresRange: Bool
    let allowsText: Bool
    let allowsStyle: Bool

    var name: String { id.rawValue }
}

struct NoteToolPayload: Codable {
    var range: Range<Int>?
    var location: Int?
    var text: String?
    var style: String?
    var includeContent: Bool?
}

struct NoteToolResult: Codable {
    var message: String
    var noteContent: String
    var selectedRange: Range<Int>?
    var metadata: [String: String]
}

enum NoteToolchainError: Error {
    case missingActiveNote
    case invalidArguments
    case unsupportedTool
}

@MainActor
final class NoteAIToolchain {
    private let workspace: NotesWorkspace

    init(workspace: NotesWorkspace) {
        self.workspace = workspace
    }

    func availableTools() -> [NoteToolDefinition] {
        [
            NoteToolDefinition(id: .readNote, displayName: "Read Note", description: "Return the full note body", requiresRange: false, allowsText: false, allowsStyle: false),
            NoteToolDefinition(id: .readSelection, displayName: "Read Selection", description: "Return a span of text given offsets", requiresRange: true, allowsText: false, allowsStyle: false),
            NoteToolDefinition(id: .replaceRange, displayName: "Replace Range", description: "Replace text in a range with new content", requiresRange: true, allowsText: true, allowsStyle: false),
            NoteToolDefinition(id: .insertText, displayName: "Insert Text", description: "Insert text at an offset", requiresRange: false, allowsText: true, allowsStyle: false),
            NoteToolDefinition(id: .deleteRange, displayName: "Delete Range", description: "Delete text within a range", requiresRange: true, allowsText: false, allowsStyle: false),
            NoteToolDefinition(id: .replaceAll, displayName: "Replace All", description: "Replace the entire note body", requiresRange: false, allowsText: true, allowsStyle: false),
            NoteToolDefinition(id: .outline, displayName: "Outline", description: "Return note headings and bullet summary", requiresRange: false, allowsText: false, allowsStyle: false),
            NoteToolDefinition(id: .metadata, displayName: "Metadata", description: "Return note metadata such as title and updated time", requiresRange: false, allowsText: false, allowsStyle: false)
        ]
    }

    func execute(toolName: String, argumentsJSONString: String) throws -> NoteToolResult {
        guard let name = NoteToolName(rawValue: toolName) else { throw NoteToolchainError.unsupportedTool }
        let rawData = argumentsJSONString.isEmpty ? Data("{}".utf8) : Data(argumentsJSONString.utf8)
        let payload = try JSONDecoder().decode(NoteToolPayload.self, from: rawData)
        return try execute(name: name, payload: payload)
    }

    func execute(name: NoteToolName, payload: NoteToolPayload) throws -> NoteToolResult {
        guard let note = workspace.selectedNote else { throw NoteToolchainError.missingActiveNote }
        switch name {
        case .readNote:
            return NoteToolResult(message: note.content, noteContent: note.content, selectedRange: nil, metadata: metadata(for: note))
        case .readSelection:
            guard let range = payload.range else { throw NoteToolchainError.invalidArguments }
            let content = note.content.text(in: range)
            return NoteToolResult(message: content, noteContent: note.content, selectedRange: range, metadata: metadata(for: note))
        case .replaceRange:
            guard let range = payload.range, let text = payload.text else { throw NoteToolchainError.invalidArguments }
            workspace.updateContent(of: note, replacing: range, with: text, editor: "assistant")
            return NoteToolResult(message: "Replaced text", noteContent: note.content, selectedRange: range.lowerBound..<(range.lowerBound + text.count), metadata: metadata(for: note))
        case .insertText:
            guard let text = payload.text else { throw NoteToolchainError.invalidArguments }
            let location = payload.location ?? note.content.count
            workspace.insertContent(into: note, at: location, text: text, editor: "assistant")
            return NoteToolResult(message: "Inserted text", noteContent: note.content, selectedRange: location..<(location + text.count), metadata: metadata(for: note))
        case .deleteRange:
            guard let range = payload.range else { throw NoteToolchainError.invalidArguments }
            workspace.deleteContent(in: note, range: range, editor: "assistant")
            return NoteToolResult(message: "Deleted text", noteContent: note.content, selectedRange: range.lowerBound..<range.lowerBound, metadata: metadata(for: note))
        case .replaceAll:
            guard let text = payload.text else { throw NoteToolchainError.invalidArguments }
            workspace.replaceAll(in: note, with: text, editor: "assistant")
            return NoteToolResult(message: "Replaced entire note", noteContent: note.content, selectedRange: 0..<text.count, metadata: metadata(for: note))
        case .outline:
            let outline = OutlineBuilder().buildOutline(from: note.content)
            return NoteToolResult(message: outline, noteContent: note.content, selectedRange: nil, metadata: metadata(for: note))
        case .metadata:
            let meta = metadata(for: note)
            let description = meta.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            return NoteToolResult(message: description, noteContent: note.content, selectedRange: nil, metadata: meta)
        }
    }

    private func metadata(for note: Note) -> [String: String] {
        [
            "note_id": note.id.uuidString,
            "title": note.title,
            "updated_at": ISO8601DateFormatter().string(from: note.updatedAt),
            "last_editor": note.lastEditor
        ]
    }
}

private struct OutlineBuilder {
    func buildOutline(from text: String) -> String {
        let lines = text.split(separator: "\n")
        var headings: [String] = []
        var bulletPoints: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") {
                headings.append(trimmed)
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                bulletPoints.append(trimmed)
            }
        }
        var parts: [String] = []
        if headings.isEmpty == false {
            parts.append("Headings:\n" + headings.joined(separator: "\n"))
        }
        if bulletPoints.isEmpty == false {
            parts.append("Bullet points:\n" + bulletPoints.joined(separator: "\n"))
        }
        if parts.isEmpty {
            parts.append("No headings or bullet points detected.")
        }
        return parts.joined(separator: "\n\n")
    }
}

private extension String {
    func text(in range: Range<Int>) -> String {
        guard let stringRange = rangeFromOffsets(range) else { return "" }
        return String(self[stringRange])
    }

    func rangeFromOffsets(_ offsets: Range<Int>) -> Range<String.Index>? {
        guard let lower = index(at: offsets.lowerBound), let upper = index(at: offsets.upperBound) else { return nil }
        return lower..<upper
    }

    func index(at offset: Int) -> String.Index? {
        guard offset >= 0, offset <= count else { return nil }
        return index(startIndex, offsetBy: offset)
    }
}
