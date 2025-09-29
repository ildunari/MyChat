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

struct NoteToolPayload: Codable, Equatable {
    var range: Range<Int>?
    var location: Int?
    var text: String?
    var style: String?
    var includeContent: Bool?

    init(range: Range<Int>? = nil,
         location: Int? = nil,
         text: String? = nil,
         style: String? = nil,
         includeContent: Bool? = nil) {
        self.range = range
        self.location = location
        self.text = text
        self.style = style
        self.includeContent = includeContent
    }
}

struct NoteToolResult: Codable {
    var message: String
    var noteContent: String
    var selectedRange: Range<Int>?
    var metadata: [String: String]
}

@MainActor
final class NoteAIToolchain {
    struct ActionPreview: Identifiable, Equatable {
        let id = UUID()
        let name: NoteToolName
        let payload: NoteToolPayload
        let description: String
        let beforeSnippet: String
        let afterSnippet: String
        let updatedContent: String
        let selection: Range<Int>?

        static let mutatingTools: Set<NoteToolName> = [.replaceRange, .insertText, .deleteRange, .replaceAll]
    }

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

    func previewAction(for note: Note, currentContent: String? = nil, name: NoteToolName, payload: NoteToolPayload) throws -> ActionPreview {
        let content = currentContent ?? note.content
        switch name {
        case .replaceRange:
            guard let range = payload.range, let replacement = payload.text else {
                throw NoteToolchainError.invalidArguments
            }
            guard let swiftRange = content.range(fromOffsets: range) else {
                throw NoteToolchainError.invalidArguments
            }
            let updatedContent = content.replacingCharacters(in: swiftRange, with: replacement)
            let newRange = range.lowerBound..<(range.lowerBound + replacement.count)
            let beforeSnippet = snippet(in: content, highlightRange: swiftRange, fallback: replacement)
            let afterSnippet = snippet(in: updatedContent, highlightOffsets: newRange, fallback: replacement)
            return ActionPreview(name: name,
                                 payload: payload,
                                 description: "Replace characters \(range.lowerBound)-\(range.upperBound)",
                                 beforeSnippet: beforeSnippet,
                                 afterSnippet: afterSnippet,
                                 updatedContent: updatedContent,
                                 selection: newRange)
        case .insertText:
            guard let insertionText = payload.text else { throw NoteToolchainError.invalidArguments }
            let location = payload.location ?? content.count
            guard let insertionIndex = content.index(at: location) else {
                throw NoteToolchainError.invalidArguments
            }
            let updatedContent = content.appending(insertionText, at: insertionIndex)
            let newRange = location..<(location + insertionText.count)
            let beforeSnippet = snippet(in: content, highlightRange: insertionIndex..<insertionIndex, fallback: insertionText)
            let afterSnippet = snippet(in: updatedContent, highlightOffsets: newRange, fallback: insertionText)
            return ActionPreview(name: name,
                                 payload: payload,
                                 description: "Insert at index \(location)",
                                 beforeSnippet: beforeSnippet,
                                 afterSnippet: afterSnippet,
                                 updatedContent: updatedContent,
                                 selection: newRange)
        case .deleteRange:
            guard let range = payload.range, let swiftRange = content.range(fromOffsets: range) else {
                throw NoteToolchainError.invalidArguments
            }
            let deleted = String(content[swiftRange])
            let updatedContent = content.replacingCharacters(in: swiftRange, with: "")
            let beforeSnippet = snippet(in: content, highlightRange: swiftRange, fallback: deleted)
            let location = min(range.lowerBound, updatedContent.count)
            let anchor = updatedContent.index(at: location) ?? updatedContent.endIndex
            let afterSnippet = snippet(in: updatedContent, highlightRange: anchor..<anchor, fallback: "")
            return ActionPreview(name: name,
                                 payload: payload,
                                 description: "Delete characters \(range.lowerBound)-\(range.upperBound)",
                                 beforeSnippet: beforeSnippet,
                                 afterSnippet: afterSnippet,
                                 updatedContent: updatedContent,
                                 selection: range.lowerBound..<range.lowerBound)
        case .replaceAll:
            guard let text = payload.text else { throw NoteToolchainError.invalidArguments }
            let beforeSnippet = snippet(in: content, highlightRange: content.startIndex..<content.endIndex, fallback: content)
            let afterSnippet = snippet(in: text, highlightRange: text.startIndex..<text.endIndex, fallback: text)
            return ActionPreview(name: name,
                                 payload: payload,
                                 description: "Replace entire note",
                                 beforeSnippet: beforeSnippet,
                                 afterSnippet: afterSnippet,
                                 updatedContent: text,
                                 selection: 0..<text.count)
        default:
            throw NoteToolchainError.unsupportedTool
        }
    }

    func applyAction(_ preview: ActionPreview, to note: Note) throws -> NoteToolResult {
        switch preview.name {
        case .replaceRange:
            guard let range = preview.payload.range, let text = preview.payload.text else {
                throw NoteToolchainError.invalidArguments
            }
            workspace.updateContent(of: note, replacing: range, with: text, editor: "assistant")
        case .insertText:
            guard let text = preview.payload.text else { throw NoteToolchainError.invalidArguments }
            let location = preview.payload.location ?? note.content.count
            workspace.insertContent(into: note, at: location, text: text, editor: "assistant")
        case .deleteRange:
            guard let range = preview.payload.range else { throw NoteToolchainError.invalidArguments }
            workspace.deleteContent(in: note, range: range, editor: "assistant")
        case .replaceAll:
            guard let text = preview.payload.text else { throw NoteToolchainError.invalidArguments }
            workspace.replaceAll(in: note, with: text, editor: "assistant")
        default:
            throw NoteToolchainError.unsupportedTool
        }

        return NoteToolResult(message: preview.description,
                              noteContent: note.content,
                              selectedRange: preview.selection,
                              metadata: metadata(for: note))
    }

    func executeReadOnly(for note: Note, name: NoteToolName, payload: NoteToolPayload) throws -> NoteToolResult {
        switch name {
        case .readNote:
            return NoteToolResult(message: note.content,
                                  noteContent: note.content,
                                  selectedRange: nil,
                                  metadata: metadata(for: note))
        case .readSelection:
            guard let range = payload.range,
                  let swiftRange = note.content.range(fromOffsets: range) else {
                throw NoteToolchainError.invalidArguments
            }
            let snippet = String(note.content[swiftRange])
            return NoteToolResult(message: snippet,
                                  noteContent: note.content,
                                  selectedRange: range,
                                  metadata: metadata(for: note))
        case .outline:
            let outline = OutlineBuilder().buildOutline(from: note.content)
            return NoteToolResult(message: outline,
                                  noteContent: note.content,
                                  selectedRange: nil,
                                  metadata: metadata(for: note))
        case .metadata:
            let meta = metadata(for: note)
            let description = meta.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            return NoteToolResult(message: description,
                                  noteContent: note.content,
                                  selectedRange: nil,
                                  metadata: meta)
        default:
            throw NoteToolchainError.unsupportedTool
        }
    }

    func execute(toolName: String, argumentsJSONString: String) throws -> NoteToolResult {
        guard let name = NoteToolName(rawValue: toolName),
              let note = workspace.selectedNote else {
            throw NoteToolchainError.unsupportedTool
        }
        let payload = try JSONDecoder().decode(NoteToolPayload.self,
                                              from: argumentsJSONString.isEmpty ? Data("{}".utf8) : Data(argumentsJSONString.utf8))
        if ActionPreview.mutatingTools.contains(name) {
            let preview = try previewAction(for: note, currentContent: note.content, name: name, payload: payload)
            return try applyAction(preview, to: note)
        } else {
            return try executeReadOnly(for: note, name: name, payload: payload)
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

    private func snippet(in text: String,
                         highlightRange: Range<String.Index>,
                         fallback: String) -> String {
        let radius = 32
        let highlight = String(text[highlightRange])
        let prefix = String(text[..<highlightRange.lowerBound].suffix(radius))
        let suffix = String(text[highlightRange.upperBound...].prefix(radius))
        let token = highlight.isEmpty ? fallback : highlight
        return "\(prefix)⟦\(token)⟧\(suffix)"
    }

    private func snippet(in text: String,
                         highlightRange: Range<String.Index>?,
                         fallback: String) -> String {
        guard let highlightRange else {
            return "⟦\(fallback)⟧"
        }
        return snippet(in: text, highlightRange: highlightRange, fallback: fallback)
    }

    private func snippet(in text: String,
                         highlightOffsets: Range<Int>,
                         fallback: String) -> String {
        guard let range = text.range(fromOffsets: highlightOffsets) else {
            return "⟦\(fallback)⟧"
        }
        return snippet(in: text, highlightRange: range, fallback: fallback)
    }
}

enum NoteToolchainError: Error {
    case missingActiveNote
    case invalidArguments
    case unsupportedTool
}

private struct OutlineBuilder {
    func buildOutline(from text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
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
        if !headings.isEmpty {
            parts.append("Headings:\n" + headings.joined(separator: "\n"))
        }
        if !bulletPoints.isEmpty {
            parts.append("Bullet points:\n" + bulletPoints.joined(separator: "\n"))
        }
        if parts.isEmpty {
            parts.append("No headings or bullet points detected.")
        }
        return parts.joined(separator: "\n\n")
    }
}

private extension String {
    func range(fromOffsets offsets: Range<Int>) -> Range<String.Index>? {
        guard let lower = index(at: offsets.lowerBound),
              let upper = index(at: offsets.upperBound) else { return nil }
        return lower..<upper
    }

    func index(at offset: Int) -> String.Index? {
        guard offset >= 0, offset <= count else { return nil }
        return index(startIndex, offsetBy: offset)
    }

    func appending(_ text: String, at index: String.Index) -> String {
        let prefix = self[..<index]
        let suffix = self[index...]
        return String(prefix) + text + String(suffix)
    }
}
