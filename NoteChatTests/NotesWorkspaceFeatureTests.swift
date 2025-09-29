import XCTest
import SwiftData
@testable import NoteChat

final class NotesWorkspaceFeatureTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var workspace: NotesWorkspace!

    override func setUpWithError() throws {
        container = try ModelContainer(for: Note.self,
                                       NoteRevision.self,
                                       NoteFolder.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        workspace = NotesWorkspace(context: context)
    }

    func testTaggingAddsUniqueValue() throws {
        let note = workspace.createNote(title: "Travel", content: "Pack list")
        workspace.addTag("Packing", to: [note])
        workspace.addTag("packing", to: [note]) // duplicate diff case
        XCTAssertEqual(note.tags.count, 1)
        XCTAssertEqual(note.tags.first?.lowercased(), "packing")
    }

    func testAssignFolderUpdatesReference() throws {
        let note = workspace.createNote(title: "Ideas", content: "Sketch new UI")
        let folder = workspace.createFolder(name: "Projects")
        workspace.assign(notes: [note], to: folder)
        XCTAssertEqual(note.folder?.id, folder.id)
    }

    func testAIReplacePreviewAndApply() throws {
        let note = workspace.createNote(title: "Demo", content: "Hello World")
        workspace.select(note: note)
        let toolchain = NoteAIToolchain(workspace: workspace)
        let payload = NoteToolPayload(range: 6..<11, text: "Universe")
        let preview = try toolchain.previewAction(for: note,
                                                  name: .replaceRange,
                                                  payload: payload)
        XCTAssertEqual(preview.updatedContent, "Hello Universe")
        _ = try toolchain.applyAction(preview, to: note)
        XCTAssertEqual(note.content, "Hello Universe")
    }

    func testDiffBuilderDetectsChanges() {
        let original = "Line1\nLine2\nLine3"
        let updated = "Line1\nLineX\nLine3\nLine4"
        let diff = DiffBuilder.buildDiff(from: original, to: updated)
        let kinds = diff.map { $0.kind }
        XCTAssertEqual(kinds.filter { $0 == .same }.count, 2)
        XCTAssertTrue(kinds.contains(.added))
        XCTAssertTrue(kinds.contains(.removed))
    }
}
