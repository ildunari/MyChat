import SwiftUI
import SwiftData

struct NotesHomeView: View {
    enum SectionKind: Hashable { case folders, quick, all }
    enum ViewMode { case multimedia, folders }

    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteFolder.createdAt, order: .forward) private var folders: [NoteFolder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var sectionOrder: [SectionKind] = [.folders, .quick, .all]
    @State private var dragOffsets: [SectionKind: CGFloat] = [:]
    @State private var foldersExpanded = true
    @State private var quickExpanded = true
    @State private var allExpanded = true
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .folders
    @State private var navNote: Note? = nil
    @State private var navFolder: NoteFolder? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(sectionOrder, id: \.self) { kind in
                        let offsetY = dragOffsets[kind] ?? 0
                        MovableSectionContainer(
                            title: title(for: kind),
                            count: count(for: kind),
                            isExpanded: bindingFor(kind),
                            maxHeight: 240,
                            draggedOffset: offsetY,
                            onDragChanged: { v in dragOffsets[kind] = v.translation.height },
                            onDragEnded: { v in onDragEnded(kind: kind, value: v) }
                        ) {
                            switch kind {
                            case .folders:
                                if viewMode == .folders { FolderGrid() } else { MultimediaGrid() }
                            case .quick:
                                QuickActions()
                            case .all:
                                NotesList()
                            }
                        }
                        .offset(y: offsetY)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search notes")
            .navigationDestination(item: $navNote) { note in
                NoteEditorView(note: note)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { withAnimation(.easeInOut) { toggleViewMode() } }) {
                        HStack(spacing: 6) {
                            if viewMode == .multimedia { AppIcon.folder(14) } else { AppIcon.image(14) }
                            Text(viewMode == .multimedia ? "Folders" : "Media")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { createNoteAndOpen() }) {
                        AppIcon.plus(16)
                    }
                    .accessibilityLabel("New Note")
                }
            }
        }
    }

    private func title(for kind: SectionKind) -> String {
        switch kind { case .folders: return viewMode == .folders ? "Folders" : "Media"; case .quick: return "Quick Actions"; case .all: return "All Notes" }
    }
    private func count(for kind: SectionKind) -> Int {
        switch kind { case .folders: return viewMode == .folders ? folders.count : notesWithAttachments().count; case .quick: return 0; case .all: return filteredNotes().count }
    }
    private func bindingFor(_ kind: SectionKind) -> Binding<Bool> {
        switch kind {
        case .folders: return $foldersExpanded
        case .quick: return $quickExpanded
        case .all: return $allExpanded
        }
    }
    private func onDragEnded(kind: SectionKind, value: DragGesture.Value) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            let threshold: CGFloat = 40
            if value.translation.height < -threshold, let idx = sectionOrder.firstIndex(of: kind), idx > 0 {
                sectionOrder.swapAt(idx, idx-1)
            } else if value.translation.height > threshold, let idx = sectionOrder.firstIndex(of: kind), idx < sectionOrder.count-1 {
                sectionOrder.swapAt(idx, idx+1)
            }
            dragOffsets[kind] = 0
        }
    }

    private func toggleViewMode() { viewMode = (viewMode == .multimedia ? .folders : .multimedia) }
    private func filteredNotes() -> [Note] {
        let base = notes
        guard searchText.isEmpty == false else { return base }
        let q = searchText.lowercased()
        return base.filter { $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q) }
    }
    private func notesWithAttachments() -> [Note] {
        // Heuristic: notes with image/code fences, can refine later
        notes.filter { n in n.content.contains("![](") || n.content.contains("```") }
    }
    private func createNoteAndOpen() {
        let note = Note(title: "New Note", content: "", createdAt: Date(), updatedAt: Date())
        modelContext.insert(note)
        try? modelContext.save()
        navNote = note
    }
}

// MARK: - Subviews

private extension NotesHomeView {
    @ViewBuilder
    func FolderGrid() -> some View {
        if folders.isEmpty {
            EmptyFolderState()
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(folders) { folder in
                    Button(action: { navFolder = folder }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { AppIcon.folder(16).foregroundStyle(T.accent); Spacer() }
                            Text(folder.name).font(.headline).foregroundStyle(T.text).lineLimit(2)
                            Text("\(folder.notes.count) notes").font(.caption).foregroundStyle(T.textSecondary)
                        }
                        .padding(12)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: T.radiusMedium).fill(T.surfaceElevated).overlay(RoundedRectangle(cornerRadius: T.radiusMedium).stroke(T.borderSoft, lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    func MultimediaGrid() -> some View {
        let items = notesWithAttachments()
        if items.isEmpty {
            VStack(spacing: 10) {
                AppIcon.image(24).foregroundStyle(T.textSecondary)
                Text("No media found in notes").foregroundStyle(T.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(T.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: T.radiusMedium))
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { note in
                    Button(action: { navNote = note }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { AppIcon.image(16).foregroundStyle(T.accent); Spacer() }
                            Text(note.title).font(.headline).foregroundStyle(T.text).lineLimit(2)
                            Text("Updated \(note.updatedAt, formatter: shortDateFormatter)").font(.caption).foregroundStyle(T.textSecondary)
                        }
                        .padding(12)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: T.radiusMedium).fill(T.surfaceElevated).overlay(RoundedRectangle(cornerRadius: T.radiusMedium).stroke(T.borderSoft, lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    func QuickActions() -> some View {
        HStack(spacing: 12) {
            ActionChip(icon: AppIcon.plus(14), title: "New Note") { createNoteAndOpen() }
            ActionChip(icon: AppIcon.folder(14), title: "New Folder") {
                let f = NoteFolder(name: "New Folder")
                modelContext.insert(f)
                try? modelContext.save()
            }
            ActionChip(icon: AppIcon.importIcon(14), title: "Import") { /* TODO */ }
            ActionChip(icon: AppIcon.wand(14), title: "AI") { /* TODO: AI actions */ }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func NotesList() -> some View {
        let data = filteredNotes()
        if data.isEmpty {
            VStack(spacing: 10) {
                AppIcon.text(24).foregroundStyle(T.textSecondary)
                Text(searchText.isEmpty ? "No notes yet" : "No results for \"\(searchText)\"")
                    .foregroundStyle(T.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(T.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: T.radiusMedium))
        } else {
            LazyVStack(spacing: 10) {
                ForEach(data) { note in
                    Button(action: { navNote = note }) {
                        HStack(alignment: .top, spacing: 12) {
                            AppIcon.note(16).foregroundStyle(T.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? "Untitled" : note.title).foregroundStyle(T.text)
                                Text(snippet(note.content, query: searchText)).font(.caption).foregroundStyle(T.textSecondary).lineLimit(2)
                            }
                            Spacer()
                            Text(shortDateFormatter.string(from: note.updatedAt)).font(.caption2).foregroundStyle(T.textSecondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(T.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Helpers

private let shortDateFormatter: DateFormatter = {
    let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short; return df
}()

private func snippet(_ text: String, query: String, radius: Int = 32) -> String {
    guard query.isEmpty == false else { return text.prefix(64) + (text.count > 64 ? "…" : "") }
    let lower = text.lowercased(); let q = query.lowercased()
    if let range = lower.range(of: q) {
        let start = lower.index(range.lowerBound, offsetBy: -min(radius, lower.distance(from: lower.startIndex, to: range.lowerBound)), limitedBy: lower.startIndex) ?? lower.startIndex
        let end = lower.index(range.upperBound, offsetBy: min(radius, lower.distance(from: range.upperBound, to: lower.endIndex)), limitedBy: lower.endIndex) ?? lower.endIndex
        return (text[start..<end]) + "…"
    }
    return text.prefix(64) + (text.count > 64 ? "…" : "")
}

private struct ActionChip: View {
    let icon: AnyView
    let title: String
    let action: () -> Void
    @Environment(\.tokens) private var T
    init(icon: some View, title: String, action: @escaping () -> Void) {
        self.icon = AnyView(icon)
        self.title = title
        self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { icon; Text(title) }
                .font(.subheadline)
                .foregroundStyle(T.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(T.surfaceElevated).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(T.borderSoft, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyFolderState: View {
    @Environment(\.tokens) private var T
    var body: some View {
        VStack(spacing: 10) {
            AppIcon.folder(24).foregroundStyle(T.textSecondary)
            Text("No folders yet").foregroundStyle(T.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(T.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: T.radiusMedium))
    }
}

