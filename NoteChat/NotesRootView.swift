import SwiftUI
import SwiftData
import Observation

struct NotesTabContainer: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NotesRootView(workspace: NotesWorkspace(context: modelContext))
    }
}

struct NotesRootView: View {
    @Environment(\.tokens) private var T
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var workspace: NotesWorkspace
    @State private var searchText: String = ""
    @State private var selection: Note.ID?
    @State private var showInspector = false

    private var filteredNotes: [Note] {
        let base = workspace.notes
        guard searchText.isEmpty == false else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    init(workspace: NotesWorkspace) {
        _workspace = StateObject(wrappedValue: workspace)
        _selection = State(initialValue: workspace.selectedNote?.id)
    }

    var body: some View {
        NavigationSplitView {
            NotesListPanel(
                notes: filteredNotes,
                selection: Binding(get: { selection }, set: { newValue in
                    selection = newValue
                    if let id = newValue, let note = workspace.notes.first(where: { $0.id == id }) {
                        workspace.select(note: note)
                    }
                }),
                workspace: workspace,
                searchText: $searchText
            )
            .toolbar { listToolbar }
        } detail: {
            if let id = selection, let note = workspace.notes.first(where: { $0.id == id }) {
                NoteDetailView(note: note,
                               workspace: workspace,
                               settingsStore: settingsStore,
                               modelContext: modelContext)
            } else {
                NotesEmptyDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selection == nil, let note = workspace.selectedNote ?? workspace.notes.first {
                selection = note.id
                workspace.select(note: note)
            }
        }
        .onChange(of: workspace.notes.count) { _, _ in
            if let selected = selection, workspace.notes.contains(where: { $0.id == selected }) == false {
                selection = workspace.notes.first?.id
            }
        }
        .sheet(isPresented: $showInspector) {
            if let id = selection, let note = workspace.notes.first(where: { $0.id == id }) {
                NoteInspectorView(note: note)
            } else {
                Text("Select a note to inspect")
                    .padding()
            }
        }
    }

    private var listToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: {
                let note = workspace.createNote()
                selection = note.id
            }) {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .accessibilityLabel("Create new note")

            Button(action: { showInspector.toggle() }) {
                Label("Note Inspector", systemImage: "info.circle")
            }
            .accessibilityLabel("Show note inspector")
        }
    }
}

private struct NotesListPanel: View {
    @Environment(\.tokens) private var T
    let notes: [Note]
    @Binding var selection: Note.ID?
    var workspace: NotesWorkspace
    @Binding var searchText: String
    @State private var pinFilter: Bool = false

    private var groupedNotes: [(title: String, items: [Note])] {
        let filtered = pinFilter ? notes.filter { $0.isPinned } : notes
        return NotesListPanel.group(notes: filtered)
    }

    var body: some View {
        List(selection: $selection) {
            if notes.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Text("No notes yet")
                            .foregroundStyle(T.textSecondary)
                        Button("Create your first note") {
                            let note = workspace.createNote()
                            selection = note.id
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(groupedNotes, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { note in
                            NotesListRow(note: note, selected: selection == note.id)
                                .tag(note.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = note.id
                                    workspace.select(note: note)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        workspace.delete(note: note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button(note.isPinned ? "Unpin" : "Pin") {
                                        workspace.update(note: note,
                                                         mutate: { $0.isPinned.toggle() },
                                                         editor: "user",
                                                         summary: note.isPinned ? "Unpinned" : "Pinned",
                                                         diff: "pin_toggle",
                                                         selection: nil)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText)
        .toolbar { pinToggle }
    }

    private var pinToggle: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $pinFilter) {
                Label("Pinned", systemImage: pinFilter ? "pin.fill" : "pin")
            }
            .toggleStyle(.switch)
        }
    }

    private static func group(notes: [Note]) -> [(title: String, items: [Note])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notes) { note -> String in
            if calendar.isDateInToday(note.updatedAt) { return "Today" }
            if calendar.isDateInYesterday(note.updatedAt) { return "Yesterday" }
            let components = calendar.dateComponents([.year, .month], from: note.updatedAt)
            if components.month != nil, components.year != nil {
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
                return formatter.string(from: note.updatedAt)
            }
            return "Older"
        }
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            guard let first = grouped[lhs]?.first, let second = grouped[rhs]?.first else { return lhs < rhs }
            return first.updatedAt > second.updatedAt
        }
        return sortedKeys.map { key in
            let items = grouped[key]?.sorted { $0.updatedAt > $1.updatedAt } ?? []
            return (title: key, items: items)
        }
    }
}

private struct NotesListRow: View {
    @Environment(\.tokens) private var T
    let note: Note
    let selected: Bool
    private var preview: String {
        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "No additional text" }
        return trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .foregroundStyle(selected ? T.accent : T.text)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(T.accent)
                }
            }
            Text(preview)
                .font(.subheadline)
                .foregroundStyle(T.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

private struct NotesEmptyDetailView: View {
    @Environment(\.tokens) private var T
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(T.textSecondary)
            Text("Select or create a note")
                .font(.title3)
                .foregroundStyle(T.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
    }
}

private struct NoteDetailView: View {
    @Environment(\.tokens) private var T
    let note: Note
    let workspace: NotesWorkspace
    let settingsStore: SettingsStore
    let modelContext: ModelContext
    private let toolchain: NoteAIToolchain
    @StateObject private var editorState: NoteEditorState
    @State private var titleDraft: String
    @State private var mode: EditorMode = .edit
    @State private var selectionRange: Range<Int> = 0..<0
    @State private var lastSavedText: String
    @State private var lastSavedTitle: String
    @State private var showAIPanel = false
    @FocusState private var titleFocused: Bool
    @State private var contentSaveWorkItem: DispatchWorkItem?
    @State private var titleSaveWorkItem: DispatchWorkItem?
    @State private var saveStatusText: String = "Saved"
    @StateObject private var session: NoteAssistantSession

    init(note: Note, workspace: NotesWorkspace, settingsStore: SettingsStore, modelContext: ModelContext) {
        self.note = note
        self.workspace = workspace
        self.settingsStore = settingsStore
        self.modelContext = modelContext
        let toolchain = NoteAIToolchain(workspace: workspace)
        self.toolchain = toolchain
        _editorState = StateObject(wrappedValue: NoteEditorState(text: note.content))
        _titleDraft = State(initialValue: note.title)
        _lastSavedText = State(initialValue: note.content)
        _lastSavedTitle = State(initialValue: note.title)
        _session = StateObject(wrappedValue: NoteAssistantSession(note: note,
                                                                  settings: settingsStore,
                                                                  toolchain: toolchain))
    }

    private var saveStatus: String {
        let hasUnsavedContent = editorState.text != lastSavedText
        let hasUnsavedTitle = titleDraft != lastSavedTitle
        
        if hasUnsavedContent || hasUnsavedTitle {
            return "Unsaved changes"
        } else if contentSaveWorkItem != nil || titleSaveWorkItem != nil {
            return "Saving..."
        } else {
            return saveStatusText
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    titleField
                    modePicker
                    HStack {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    editorStack
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            Divider()
            NoteEditingToolbar(onChecklist: insertChecklist,
                                onFormatting: toggleFormattingSuggestions,
                                onAI: { showAIPanel = true },
                                onSketch: startSketch)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .background(T.surface.opacity(0.95).ignoresSafeArea())
        .toolbar { detailToolbar }
        .sheet(isPresented: $showAIPanel) {
            NotesAIPanel(session: session,
                         editorState: editorState,
                         isPresented: $showAIPanel,
                         onContentApplied: { newText in
                             lastSavedText = newText
                             saveStatusText = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
                         })
        }
        .onChange(of: editorState.text) { _, newValue in
            scheduleContentSave(newValue)
        }
        .onChange(of: titleDraft) { _, newValue in
            scheduleTitleSave(newValue)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(T.surface.opacity(0.45))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.crop.circle").font(.system(size: 20, weight: .medium)).foregroundStyle(T.textSecondary))

            Spacer()

            Button(action: shareNote) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .padding(10)
                    .background(T.surface.opacity(0.35), in: Capsule())
            }

            Button(action: { }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .padding(10)
                    .background(T.surface.opacity(0.35), in: Circle())
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $titleDraft)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(T.text)
                .focused($titleFocused)
                .textInputAutocapitalization(.sentences)
            Text(relativeDate(note.updatedAt))
                .font(.footnote)
                .foregroundStyle(T.textSecondary)
        }
        .padding(.bottom, 12)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Edit").tag(EditorMode.edit)
            Text("Preview").tag(EditorMode.preview)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var editorStack: some View {
        switch mode {
        case .edit:
            NoteTextEditor(state: editorState,
                           placeholder: "Start writing…",
                           onTextChange: { _ in },
                           onSelectionChange: handleSelectionChange)
                .frame(minHeight: 420, maxHeight: .infinity, alignment: .topLeading)
        case .preview:
            NoteMarkdownPreview(text: editorState.text)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: duplicateNote) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button(role: .destructive, action: deleteNote) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleSelectionChange(_ range: NSRange) {
        if let converted = range.toIntRange(in: editorState.text) {
            selectionRange = converted
        }
    }

    private func scheduleContentSave(_ text: String) {
        contentSaveWorkItem?.cancel()
        saveStatusText = "Saving…"
        let workItem = DispatchWorkItem { [text] in
            guard text != lastSavedText else {
                saveStatusText = "Saved"
                return
            }
            workspace.update(note: note,
                             mutate: { $0.content = text },
                             editor: "user",
                             summary: "Body updated",
                             diff: "body_update",
                             selection: selectionRange)
            lastSavedText = text
            saveStatusText = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
        }
        contentSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func scheduleTitleSave(_ title: String) {
        titleSaveWorkItem?.cancel()
        saveStatusText = "Saving…"
        let workItem = DispatchWorkItem { [title] in
            guard title != lastSavedTitle else {
                saveStatusText = "Saved"
                return
            }
            workspace.update(note: note,
                             mutate: { $0.title = title },
                             editor: "user",
                             summary: "Title updated",
                             diff: "title_update",
                             selection: nil)
            lastSavedTitle = title
            saveStatusText = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
        }
        titleSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func insertChecklist() {
        let insertion = selectionRange.lowerBound
        workspace.insertContent(into: note, at: insertion, text: "- ", editor: "user")
        editorState.text = note.content
    }

    private func toggleFormattingSuggestions() {
        mode = mode == .edit ? .preview : .edit
    }

    private func startSketch() {
        // Placeholder for drawing integration
    }

    private func shareNote() {
        // TODO: integrate share sheet in future iteration
    }

    private func duplicateNote() {
        let _ = workspace.createNote(title: note.title + " Copy", content: note.content)
    }

    private func deleteNote() {
        workspace.delete(note: note)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date()).capitalized
    }

    private enum EditorMode: Hashable {
        case edit
        case preview
    }
}

private struct NoteMarkdownPreview: View {
    @Environment(\.tokens) private var T
    let text: String
    var body: some View {
        let attributed = renderMarkdownAttributed(text, linkColor: T.link, preferSystemStyling: true)
        return Text(attributed)
            .font(.body)
            .foregroundStyle(T.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(.top, 8)
    }
}

private struct NoteEditingToolbar: View {
    var onChecklist: () -> Void
    var onFormatting: () -> Void
    var onAI: () -> Void
    var onSketch: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onChecklist) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .medium))
            }
            Button(action: onSketch) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 18, weight: .medium))
            }
            Spacer()
            Button(action: onAI) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
            }
            Button(action: onFormatting) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(Color.primary)
    }
}

private struct NotesAIPanel: View {
    @ObservedObject var session: NoteAssistantSession
    @ObservedObject var editorState: NoteEditorState
    @Binding var isPresented: Bool
    @State private var prompt: String = ""
    @State private var isSending: Bool = false
    var onContentApplied: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(session.messages.enumerated()), id: \.offset) { idx, entry in
                                messageView(for: entry)
                                    .id(idx)
                            }
                        }
                        .onChange(of: session.messages.count) { _, _ in
                            withAnimation { proxy.scrollTo(session.messages.count - 1, anchor: .bottom) }
                            let latest = session.currentNote.content
                            editorState.text = latest
                            onContentApplied(latest)
                        }
                    }
                }

                TextField("Ask the assistant to edit…", text: $prompt, axis: .vertical)
                    .lineLimit(1...4)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: runPrompt) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Send", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSending || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .navigationTitle("Note Assistant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(for entry: NoteAssistantSession.MessageRole) -> some View {
        switch entry {
        case .user(let text):
            Text(text)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(12)
                .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .assistant(let text):
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .tool(let text):
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func runPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        isSending = true
        let currentPrompt = trimmed
        prompt = ""
        Task {
            await session.send(prompt: currentPrompt)
            await MainActor.run {
                isSending = false
                let latest = session.currentNote.content
                editorState.text = latest
                onContentApplied(latest)
            }
        }
    }
}

private struct NoteInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    private var revisions: [NoteRevision] {
        note.revisions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Metadata") {
                    LabeledContent("Title", value: note.title.isEmpty ? "Untitled" : note.title)
                    LabeledContent("Created", value: note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Updated", value: note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Pinned", value: note.isPinned ? "Yes" : "No")
                    if note.tags.isEmpty == false {
                        LabeledContent("Tags", value: note.tags.joined(separator: ", "))
                    }
                }

                Section("Revisions") {
                    if revisions.isEmpty {
                        Text("No revisions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(revisions) { revision in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(revision.summary)
                                        .font(.headline)
                                    Spacer()
                                    Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Editor: \(revision.editor)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if revision.appliedDiff.isEmpty == false {
                                    Text(revision.appliedDiff)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Note Inspector")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension NSRange {
    func toIntRange(in text: String) -> Range<Int>? {
        guard let swiftRange = Range(self, in: text) else { return nil }
        let lower = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let upper = text.distance(from: text.startIndex, to: swiftRange.upperBound)
        return lower..<upper
    }
}

#Preview {
    NotesTabContainer()
        .modelContainer(for: [Note.self, NoteRevision.self, Chat.self, Message.self, AppSettings.self], inMemory: true)
}
