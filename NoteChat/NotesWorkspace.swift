import Foundation
import SwiftData
import Combine

@MainActor
final class NotesWorkspace: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedNote: Note?

    private let context: ModelContext
    private var fetchDescriptor: FetchDescriptor<Note>

    init(context: ModelContext) {
        self.context = context
        self.fetchDescriptor = FetchDescriptor<Note>()
        reload()
        selectedNote = notes.first
    }

    func reload() {
        let allNotes = (try? context.fetch(fetchDescriptor)) ?? []
        // Sort manually after fetching
        notes = allNotes.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }
            return first.updatedAt > second.updatedAt
        }
        if let selected = selectedNote, !notes.contains(where: { $0.id == selected.id }) {
            selectedNote = notes.first
        }
    }

    @discardableResult
    func createNote(title: String = "Untitled", content: String = "") -> Note {
        let now = Date()
        let note = Note(title: title, content: content, createdAt: now, updatedAt: now)
        context.insert(note)
        try? context.save()
        recordRevision(for: note, summary: "Note created", diff: content, editor: "user", selectionRange: nil)
        reload()
        selectedNote = note
        return note
    }

    func delete(note: Note) {
        context.delete(note)
        try? context.save()
        reload()
    }

    func select(note: Note?) {
        selectedNote = note
    }

    func update(note: Note, mutate: (Note) -> Void, editor: String = "user", summary: String = "Updated", diff: String = "", selection: Range<Int>? = nil) {
        let originalUpdated = note.updatedAt
        mutate(note)
        note.updatedAt = Date()
        note.lastEditor = editor
        note.lastSummary = summary
        try? context.save()
        if diff.isEmpty == false || summary != "Updated" || editor != "user" {
            recordRevision(for: note, summary: summary, diff: diff, editor: editor, selectionRange: selection)
        } else if originalUpdated != note.updatedAt {
            recordRevision(for: note, summary: "Auto-save", diff: note.content, editor: editor, selectionRange: selection)
        }
        reload()
    }

    func recordRevision(for note: Note, summary: String, diff: String, editor: String, selectionRange: Range<Int>?) {
        let revision = NoteRevision(createdAt: Date(), editor: editor, summary: summary, appliedDiff: diff, selectionRange: selectionRange, note: note)
        context.insert(revision)
        try? context.save()
    }
}

extension NotesWorkspace {
    func updateContent(of note: Note, replacing range: Range<Int>, with text: String, editor: String) {
        let current = note.content
        guard let swiftRange = current.range(for: range) else { return }
        let newContent = current.replacingCharacters(in: swiftRange, with: text)
        let diff = "replace[\(range.lowerBound)..<\(range.upperBound)] -> \(text)"
        update(note: note, mutate: { item in item.content = newContent }, editor: editor, summary: "Edited content", diff: diff, selection: range.lowerBound..<(range.lowerBound + text.count))
    }

    func insertContent(into note: Note, at index: Int, text: String, editor: String) {
        let boundedIndex = max(0, min(index, note.content.count))
        let current = note.content
        let insertionPoint = current.index(from: boundedIndex)
        let prefix = String(current[..<insertionPoint])
        let suffix = String(current[insertionPoint...])
        let newContent = prefix + text + suffix
        let diff = "insert@\(boundedIndex): \(text)"
        update(note: note, mutate: { item in item.content = String(newContent) }, editor: editor, summary: "Inserted content", diff: diff, selection: boundedIndex..<(boundedIndex + text.count))
    }

    func deleteContent(in note: Note, range: Range<Int>, editor: String) {
        let current = note.content
        guard let swiftRange = current.range(for: range) else { return }
        let deleted = String(current[swiftRange])
        let newContent = current.replacingCharacters(in: swiftRange, with: "")
        let diff = "delete[\(range.lowerBound)..<\(range.upperBound)]: \(deleted)"
        update(note: note, mutate: { item in item.content = newContent }, editor: editor, summary: "Deleted content", diff: diff, selection: range.lowerBound..<range.lowerBound)
    }

    func replaceAll(in note: Note, with text: String, editor: String) {
        let diff = "replace_all"
        update(note: note, mutate: { item in item.content = text }, editor: editor, summary: "Replaced content", diff: diff, selection: 0..<text.count)
    }
}

private extension String {
    func range(for offsets: Range<Int>) -> Range<String.Index>? {
        guard let lower = index(at: offsets.lowerBound), let upper = index(at: offsets.upperBound) else { return nil }
        return lower..<upper
    }

    func index(at offset: Int) -> String.Index? {
        guard offset >= 0, offset <= count else { return nil }
        return index(startIndex, offsetBy: offset)
    }

    func index(from offset: Int) -> String.Index {
        index(startIndex, offsetBy: max(0, min(offset, count)))
    }
}
