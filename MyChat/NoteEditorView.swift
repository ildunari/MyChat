import SwiftUI
import SwiftData

struct NoteEditorView: View, Identifiable {
    var id: UUID { note.id }
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @State private var mode: EditorMode = .edit
    @State private var titleDraft: String = ""
    @Bindable var note: Note

    enum EditorMode { case edit, preview }

    init(note: Note) {
        self.note = note
        _titleDraft = State(initialValue: note.title)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Title", text: $titleDraft, axis: .vertical)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(T.surfaceElevated)
                .onSubmit { applyTitle() }
                .onChange(of: titleDraft) { _, _ in debounceApplyTitle() }

            // Formatting toolbar
            FormattingToolbar(apply: applyFormatting)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(T.surface.opacity(0.9))

            Divider()

            Group {
                if mode == .edit {
                    NoteMarkdownEditor(text: $note.content)
                        .background(T.surface)
                        .onChange(of: note.content) { _, _ in scheduleAutosave() }
                } else {
                    ScrollView {
                        Text(renderMarkdownAttributed(note.content, linkColor: T.accent))
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(T.surface)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Mode", selection: $mode) {
                    Text("Edit").tag(EditorMode.edit)
                    Text("Preview").tag(EditorMode.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: saveNow) { AppIcon.check(16) }
                    .accessibilityLabel("Save")
            }
        }
        .onDisappear { saveNow() }
    }

    private func applyTitle() { note.title = titleDraft; saveNow() }
    private func debounceApplyTitle() { scheduleAutosave() }
    private func saveNow() { note.updatedAt = Date(); try? modelContext.save() }
    @State private var pendingSaveWorkItem: DispatchWorkItem? = nil
    private func scheduleAutosave() {
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { saveNow() }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    // Insert simple markdown tokens
    private func applyFormatting(_ action: FormattingAction) {
        switch action {
        case .bold:
            wrapSelection(prefix: "**", suffix: "**", placeholder: "bold")
        case .italic:
            wrapSelection(prefix: "_", suffix: "_", placeholder: "italic")
        case .heading:
            insertAtLineStart("# ")
        case .list:
            insertAtLineStart("- ")
        case .code:
            wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
        case .link:
            wrapSelection(prefix: "[", suffix: "](https://)", placeholder: "text")
        }
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        // Fallback: append tokens if selection is unknown (TextEditor limitation)
        note.content += "\n\(prefix)\(placeholder)\(suffix)"
        saveNow()
    }
    private func insertAtLineStart(_ token: String) {
        note.content += "\n\(token)"
        saveNow()
    }
}

// MARK: - Formatting Toolbar

enum FormattingAction { case bold, italic, heading, list, code, link }

private struct FormattingToolbar: View {
    @Environment(\.tokens) private var T
    let apply: (FormattingAction) -> Void
    var body: some View {
        HStack(spacing: 12) {
            Group {
                Button { apply(.bold) } label: { AppIcon.bold(14) }
                Button { apply(.italic) } label: { AppIcon.italic(14) }
                Button { apply(.heading) } label: { AppIcon.h1(14) }
                Button { apply(.list) } label: { AppIcon.list(14) }
                Button { apply(.code) } label: { AppIcon.code(14) }
                Button { apply(.link) } label: { AppIcon.link(14) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(T.text)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(T.surfaceElevated)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(T.borderSoft, lineWidth: 1))
        )
    }
}

// MARK: - Minimal Markdown TextEditor (SwiftUI native)

private struct MarkdownTextEditor: View {
    @Binding var text: String
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .rounded))
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
