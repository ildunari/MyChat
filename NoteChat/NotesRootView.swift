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
    @State private var multiSelection: Set<Note.ID> = []
    @State private var editMode: EditMode = .inactive
    @State private var folderFilter: NoteFolder?
    @State private var tagFilter: String?
    @State private var showCreateFolderSheet = false
    @State private var newFolderName: String = ""
    @State private var showAddTagSheet = false
    @State private var newTagText: String = ""

    private var filteredNotes: [Note] {
        var base = workspace.notes
        if let folder = folderFilter {
            base = base.filter { $0.folder?.id == folder.id }
        }
        if let tag = tagFilter {
            base = base.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
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
                multiSelection: $multiSelection,
                editMode: $editMode,
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
        .environment(\.editMode, $editMode)
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
        .onChange(of: editMode) { _, mode in
            if mode != .active {
                multiSelection.removeAll()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editMode == .active && !multiSelection.isEmpty {
                multiSelectionBar
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showInspector) {
            if let id = selection, let note = workspace.notes.first(where: { $0.id == id }) {
                NoteInspectorView(note: note, workspace: workspace)
            } else {
                Text("Select a note to inspect")
                    .padding()
            }
        }
        .sheet(isPresented: $showCreateFolderSheet, onDismiss: { newFolderName = "" }) {
            newFolderSheet
        }
        .sheet(isPresented: $showAddTagSheet, onDismiss: { newTagText = "" }) {
            addTagSheet
        }
    }

    @ToolbarContentBuilder
    private var listToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Menu {
                Button("All Folders") { folderFilter = nil }
                ForEach(workspace.folders) { folder in
                    Button(folder.name) { folderFilter = folder }
                }
                Divider()
                Button("New Folder…") { showCreateFolderSheet = true }
            } label: {
                Label(folderFilter?.name ?? "Folders", systemImage: "folder")
            }

            Menu {
                Button("All Tags") { tagFilter = nil }
                if workspace.availableTags.isEmpty {
                    Text("No tags yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspace.availableTags, id: \.self) { tag in
                        Button(tag) { tagFilter = tag }
                    }
                }
            } label: {
                Label(tagFilter ?? "Tags", systemImage: "tag")
            }
        }

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

            EditButton()
        }
    }

    private var multiSelectionBar: some View {
        VStack(spacing: 12) {
            Text("\(multiSelection.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    showAddTagSheet = true
                } label: {
                    Label("Add Tag", systemImage: "tag.badge.plus")
                }

                Menu {
                    Button("No Folder") { assignSelection(to: nil) }
                    ForEach(workspace.folders) { folder in
                        Button(folder.name) { assignSelection(to: folder) }
                    }
                    Divider()
                    Button("New Folder…") { showCreateFolderSheet = true }
                } label: {
                    Label("Folder", systemImage: "folder.fill")
                }

                Button {
                    workspace.togglePinned(notes: selectedNotes(), pinned: true)
                    exitEditMode()
                } label: {
                    Label("Pin", systemImage: "pin")
                }

                Button {
                    workspace.togglePinned(notes: selectedNotes(), pinned: false)
                    exitEditMode()
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }

                Button(role: .destructive) {
                    deleteSelection()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    private var newFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("Name", text: $newFolderName)
                }
            }
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateFolderSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else { return }
                        let folder = workspace.createFolder(name: trimmed)
                        assignSelection(to: folder)
                        newFolderName = ""
                        showCreateFolderSheet = false
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var addTagSheet: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    TextField("Tag", text: $newTagText)
                }
            }
            .navigationTitle("Add Tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTagSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else { return }
                        workspace.addTag(trimmed, to: selectedNotes())
                        newTagText = ""
                        exitEditMode()
                        showAddTagSheet = false
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func selectedNotes() -> [Note] {
        workspace.notes.filter { multiSelection.contains($0.id) }
    }

    private func assignSelection(to folder: NoteFolder?) {
        let notes = selectedNotes()
        guard notes.isEmpty == false else { return }
        workspace.assign(notes: notes, to: folder)
        selection = notes.first?.id ?? selection
        exitEditMode()
    }

    private func deleteSelection() {
        let notes = selectedNotes()
        guard notes.isEmpty == false else { return }
        workspace.delete(notes: notes)
        selection = workspace.notes.first?.id
        exitEditMode()
    }

    private func exitEditMode() {
        editMode = .inactive
        multiSelection.removeAll()
    }
}

private struct NotesListPanel: View {
    @Environment(\.tokens) private var T
    let notes: [Note]
    @Binding var selection: Note.ID?
    @Binding var multiSelection: Set<Note.ID>
    @Binding var editMode: EditMode
    var workspace: NotesWorkspace
    @Binding var searchText: String
    @State private var pinFilter: Bool = false

    private var groupedNotes: [(title: String, items: [Note])] {
        let filtered = pinFilter ? notes.filter { $0.isPinned } : notes
        return NotesListPanel.group(notes: filtered)
    }

    private var listSelection: Binding<Set<Note.ID>> {
        Binding {
            if editMode == .active {
                return multiSelection
            } else if let selection {
                return Set([selection])
            } else {
                return []
            }
        } set: { newValue in
            if editMode == .active {
                multiSelection = newValue
            } else {
                selection = newValue.first
            }
        }
    }

    var body: some View {
        List(selection: listSelection) {
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
                            NotesListRow(note: note,
                                         selected: selection == note.id)
                                .tag(note.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        workspace.delete(note: note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button(note.isPinned ? "Unpin" : "Pin") {
                                        workspace.togglePinned(notes: [note], pinned: !note.isPinned)
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
            HStack(spacing: 6) {
                if let folder = note.folder {
                    Label(folder.name, systemImage: "folder")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(T.textSecondary.opacity(0.8))
                        .help(folder.name)
                }
                if note.tags.isEmpty == false {
                    Text(note.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(T.textSecondary)
                }
            }
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, DockMetrics.expandedHeight + 120)
            }

            NoteEditingToolbar(onChecklist: insertChecklist,
                                onFormatting: toggleFormattingSuggestions,
                                onAI: { showAIPanel = true },
                                onSketch: startSketch)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
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
            glassIconButton(systemName: "person.crop.circle")

            Spacer(minLength: 12)

            glassIconButton(systemName: "square.and.arrow.up", action: shareNote)
            glassIconButton(systemName: "ellipsis", action: { })
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $titleDraft)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(T.text)
                .focused($titleFocused)
                .textInputAutocapitalization(.sentences)
            Text(relativeDate(note.updatedAt))
                .font(.footnote)
                .foregroundStyle(T.textSecondary)
        }
        .padding(.bottom, 8)
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
        var attributed = renderMarkdownAttributed(text, linkColor: T.link, preferSystemStyling: true)
        attributed = attributed.applyingParagraphStyle(lineSpacing: 6, paragraphSpacing: 12)

        return Text(attributed)
            .foregroundStyle(T.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(.top, 8)
    }
}

private struct NoteEditingToolbar: View {
    @Environment(\.tokens) private var T
    var onChecklist: () -> Void
    var onFormatting: () -> Void
    var onAI: () -> Void
    var onSketch: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            glassToolButton(systemName: "checklist", action: onChecklist)
            glassToolButton(systemName: "pencil.tip", action: onSketch)
            glassToolButton(systemName: "sparkles", action: onAI)
            glassToolButton(systemName: "text.badge.plus", action: onFormatting)
        }
    }

    private func glassToolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(T.text)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(T.borderSoft.opacity(0.35), lineWidth: 0.7))
                )
        }
        .buttonStyle(.plain)
        .shadow(color: T.shadow.opacity(0.18), radius: 10, y: 8)
    }
}

extension NoteDetailView {
    @ViewBuilder
    private func glassIconButton(systemName: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(T.text)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(T.borderSoft.opacity(0.45), lineWidth: 0.7)
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: T.shadow.opacity(0.18), radius: 8, y: 6)
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
                            if let streaming = session.streamingThought, streaming.isEmpty == false {
                                Text(streaming)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .id("streaming")
                            }
                        }
                        .onChange(of: session.messages.count) { _, _ in
                            withAnimation { proxy.scrollTo(session.messages.count - 1, anchor: .bottom) }
                            syncEditor()
                        }
                        .onChange(of: session.streamingThought) { _, _ in
                            withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                        }
                    }
                }

                if !session.pendingPreviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Proposed Changes")
                                .font(.headline)
                            Spacer()
                            Button("Apply All") { applyAllPreviews() }
                                .disabled(isSending)
                        }
                        ForEach(session.pendingPreviews) { preview in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(preview.description)
                                    .font(.subheadline.weight(.semibold))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Before")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(preview.beforeSnippet)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                    Text("After")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(preview.afterSnippet)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                HStack {
                                    Button("Apply") { apply(preview: preview) }
                                        .buttonStyle(.borderedProminent)
                                    Button("Discard") { discard(preview: preview) }
                                        .buttonStyle(.bordered)
                                }
                            }
                            .padding(12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                if let error = session.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .system(let text):
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
            syncEditor()
            isSending = false
        }
    }

    private func apply(preview: NoteAIToolchain.ActionPreview) {
        session.apply(preview: preview)
        syncEditor()
    }

    private func discard(preview: NoteAIToolchain.ActionPreview) {
        session.discard(preview: preview)
    }

    private func applyAllPreviews() {
        session.applyAllPreviews()
        syncEditor()
    }

    private func syncEditor() {
        let latest = session.currentNote.content
        editorState.text = latest
        onContentApplied(latest)
    }
}

private struct NoteInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note
    let workspace: NotesWorkspace

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
                    if let folder = note.folder {
                        LabeledContent("Folder", value: folder.name)
                    }
                }

                Section("Revisions") {
                    if revisions.isEmpty {
                        Text("No revisions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(revisions) { revision in
                            NavigationLink(value: revision.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(revision.summary)
                                        .font(.subheadline.weight(.semibold))
                                    Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Note Inspector")
            .navigationDestination(for: UUID.self) { revisionID in
                if let revision = revisions.first(where: { $0.id == revisionID }) {
                    RevisionDetailView(note: note,
                                       revision: revision,
                                       onRestore: {
                                           workspace.restore(note: note, to: revision)
                                       })
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RevisionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note
    let revision: NoteRevision
    let onRestore: () -> Void
    @State private var showRestoreConfirm = false

    private var diffLines: [DiffLine] {
        DiffBuilder.buildDiff(from: revision.contentSnapshot, to: note.content)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(revision.summary)
                        .font(.title3.weight(.semibold))
                    Text("Edited by \(revision.editor) on \(revision.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Diff vs. current")
                        .font(.headline)
                    ForEach(diffLines) { line in
                        Text(line.description)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(line.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(20)
        }
        .navigationTitle("Revision")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Restore") { showRestoreConfirm = true }
            }
        }
        .alert("Restore Revision?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                onRestore()
                dismiss()
            }
        } message: {
            Text("This will replace the note content with the snapshot from this revision.")
        }
    }
}

struct DiffLine: Identifiable {
    enum Kind { case same, added, removed }
    let id = UUID()
    let kind: Kind
    let text: String

    var description: String {
        switch kind {
        case .same: return "  " + text
        case .added: return "+ " + text
        case .removed: return "- " + text
        }
    }

    var color: Color {
        switch kind {
        case .same: return .primary
        case .added: return .green
        case .removed: return .red
        }
    }
}

enum DiffBuilder {
    static func buildDiff(from old: String, to new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let lcsTable = longestCommonSubsequenceTable(old: oldLines, new: newLines)
        var result: [DiffLine] = []
        var i = oldLines.count
        var j = newLines.count
        while i > 0 || j > 0 {
            if i > 0, j > 0, oldLines[i - 1] == newLines[j - 1] {
                result.append(DiffLine(kind: .same, text: oldLines[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0, (i == 0 || lcsTable[i][j - 1] >= lcsTable[i - 1][j]) {
                result.append(DiffLine(kind: .added, text: newLines[j - 1]))
                j -= 1
            } else if i > 0, (j == 0 || lcsTable[i][j - 1] < lcsTable[i - 1][j]) {
                result.append(DiffLine(kind: .removed, text: oldLines[i - 1]))
                i -= 1
            }
        }
        return result.reversed()
    }

    private static func longestCommonSubsequenceTable(old: [String], new: [String]) -> [[Int]] {
        let m = old.count
        let n = new.count
        var table = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0..<m {
            for j in 0..<n {
                if old[i] == new[j] {
                    table[i + 1][j + 1] = table[i][j] + 1
                } else {
                    table[i + 1][j + 1] = max(table[i][j + 1], table[i + 1][j])
                }
            }
        }
        return table
    }
}

private extension AttributedString {
    func applyingParagraphStyle(lineSpacing: CGFloat, paragraphSpacing: CGFloat) -> AttributedString {
        let mutable = NSMutableAttributedString(attributedString: NSAttributedString(self))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
        return AttributedString(mutable)
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
