import SwiftUI
import SwiftData

enum MainTab: Int, CaseIterable { case chat, notes, home, media, settings }

struct RootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var store
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var tab: MainTab = .home
    @Namespace private var highlightNS
    @StateObject private var chatBridge = ChatComposerBridge()

    var body: some View {
        ZStack {
            // Liquid glass background spans the app (toggleable), respects Reduce Transparency
            if store.useLiquidGlass {
                LiquidGlassBackground()
                    .allowsHitTesting(false)
                    .opacity(reduceTransparency ? 0 : store.liquidGlassIntensity)
            }
            Group {
                switch tab {
                case .home: ContentView()
                case .chat: ChatRootView()
                case .notes: NotesPlaceholderView()
                case .media: MediaPlaceholderView()
                case .settings: SettingsView()
                }
            }
        // Ensure scrollable content never goes underneath the dock
        .safeAreaPadding(.bottom, DockMetrics.height)
        .environmentObject(chatBridge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                // Composer overlays above the dock when in Chat tab
                if tab == .chat {
                    InputBar(text: $chatBridge.text,
                             onSend: { chatBridge.onSend?() },
                             isStreaming: chatBridge.isStreaming,
                             onStop: { chatBridge.onStop?() },
                             onMic: { chatBridge.onMic?() },
                             onLive: { chatBridge.onLive?() },
                             onPlus: { chatBridge.onPlus?() })
                    .padding(.horizontal)
                    .padding(.bottom, DockMetrics.height + 6) // sit above dock
                    .zIndex(1)
                }

                DockTabBar(selected: $tab, highlightNS: highlightNS)
                    .zIndex(0)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        }
        .background(T.bg.opacity(0.4).ignoresSafeArea())
        // Respond to global open-chat events from anywhere (e.g., Home)
        .onReceive(NotificationCenter.default.publisher(for: AppNavEvent.openChat)) { _ in
            withAnimation(.spring()) { tab = .chat }
        }
    }
}

private struct DockTabBar: View {
    @Environment(\.tokens) private var T
    @Environment(\.colorScheme) private var scheme
    @Binding var selected: MainTab
    var highlightNS: Namespace.ID

    private struct Item { let tab: MainTab; let title: String; let icon: AnyView }
    private var items: [Item] {
        [
            .init(tab: .chat, title: "Chat", icon: AnyView(AppIcon.chat(20))),
            .init(tab: .notes, title: "Notes", icon: AnyView(AppIcon.note(20))),
            .init(tab: .home, title: "Home", icon: AnyView(AppIcon.home(20))),
            .init(tab: .media, title: "Media", icon: AnyView(AppIcon.image(20))),
            .init(tab: .settings, title: "Settings", icon: AnyView(AppIcon.gear(20)))
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { it in
                Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selected = it.tab } }) {
                    VStack(spacing: 6) {
                        ZStack {
                            if selected == it.tab {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(T.accent)
                                    .matchedGeometryEffect(id: "hl", in: highlightNS)
                                    .frame(width: 68, height: 52) // taller to center highlight
                            }
                            VStack(spacing: 4) {
                                it.icon
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                                Text(it.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                            }
                            .frame(width: 76, height: 56)
                            .padding(.horizontal, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
        .background(
            // Solid dock background so content doesn't show through
            // (prevents scroll views from appearing "behind" the dock)
            RoundedRectangle(cornerRadius: 0)
                .fill(T.surface) // opaque surface color
                .overlay(
                    Rectangle().fill(T.borderSoft).frame(height: 0.5), alignment: .top
                )
                .shadow(color: T.shadow.opacity(0.10), radius: 14, x: 0, y: -2)
        )
    }
}

enum DockMetrics { static let height: CGFloat = 78 }

// MARK: - Chat Root with left drawer

private struct ChatRootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var store
    @EnvironmentObject private var chatBridge: ChatComposerBridge
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    @State private var current: Chat? = nil
    @State private var drawerX: CGFloat = -1 // -1 closed, 0 open (as fraction of width)
    @State private var drawerOpen: Bool = false
    @State private var search: String = ""

    var body: some View {
        GeometryReader { geo in
            let maxWidth = geo.size.width * 0.66
            ZStack(alignment: .leading) {
                // Chat content behind
                if let chat = current ?? chats.first {
                    NavigationStack {
                        ChatView(chat: chat, onNewChat: {
                            let newChat = Chat(title: "New Chat")
                            modelContext.insert(newChat)
                            try? modelContext.save()
                            withAnimation(.spring()) { current = newChat }
                        })
                    }
                } else {
                    Text("No chats yet. Tap + to start.")
                        .foregroundStyle(T.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Drawer panel
                drawer
                    .frame(width: maxWidth)
                    .offset(x: -maxWidth + maxWidth * max(0, drawerX))
                    .shadow(color: T.shadow.opacity(0.3), radius: 12, x: 8, y: 0)

                // Scrim
                if drawerX > 0.01 {
                    Color.black.opacity(0.25 * drawerX)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring()) { drawerX = -1 } }
                }
                if drawerX <= -0.98 { // edge affordance when closed
                    HStack(spacing: 0) {
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 3)
                                .fill(T.borderHard)
                                .frame(width: 4, height: 28)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in
                        if v.startLocation.x < 16 || drawerX > 0 { // edge or already open
                            let maxW = maxWidth
                            drawerX = max(-1, min(0, -1 + v.translation.width / maxW))
                        }
                    }
                    .onEnded { v in
                        let open = drawerX > -0.5 || v.velocity.width > 200
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { drawerX = open ? 0 : -1 }
                        if open != drawerOpen { Haptics.selection(); drawerOpen = open }
                    }
            )
            .onAppear {
                if current == nil {
                    if let first = chats.first {
                        current = first
                    } else {
                        // Auto-create a fresh chat when none exist
                        let newChat = Chat(title: "New Chat")
                        modelContext.insert(newChat)
                        try? modelContext.save()
                        current = newChat
                    }
                }
            }
            // Save/load per-chat drafts when switching threads
            .onChange(of: current) { oldChat, newChat in
                guard store.preserveDrafts else { return }
                if let oldId = oldChat?.id { chatBridge.saveDraft(for: oldId) }
                if let newId = newChat?.id { chatBridge.loadDraft(for: newId) }
            }
            // Jump directly to a requested chat
            .onReceive(NotificationCenter.default.publisher(for: AppNavEvent.openChat)) { note in
                if let id = note.userInfo?["id"] as? UUID,
                   let target = chats.first(where: { $0.id == id }) {
                    withAnimation(.spring()) { current = target; drawerX = -1 }
                }
            }
        }
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History").font(.headline).foregroundStyle(T.text)
                Spacer()
                Button(role: .destructive, action: { showClearAll.toggle() }) {
                    HStack(spacing: 6) { AppIcon.trash(14); Text("Clear All") }
                }
                .buttonStyle(.bordered)
                .tint(Color.red)
                Button(action: { withAnimation(.spring()) { drawerX = -1 } }) { AppIcon.close(14) }
                    .buttonStyle(.plain)
            }
            .padding(12)
            .background(T.surfaceElevated)
            .overlay(Rectangle().fill(T.borderSoft).frame(height: 1), alignment: .bottom)

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search chats", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(T.surface)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredAndSortedChats) { c in
                        Button(action: { current = c; withAnimation(.spring()) { drawerX = -1 } }) {
                            HStack {
                                if c.isPinned { Image(systemName: "pin.fill").foregroundStyle(T.accent) } else { AppIcon.text(16).foregroundStyle(T.accent) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title.isEmpty ? "New Chat" : c.title).foregroundStyle(T.text)
                                        .lineLimit(1)
                                    Text(relative(c.createdAt)).font(.caption).foregroundStyle(T.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(T.surface)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(c.isPinned ? "Unpin" : "Pin") { c.isPinned.toggle(); try? modelContext.save() }
                            Divider()
                            Button("Delete", role: .destructive) { modelContext.delete(c); try? modelContext.save(); if current?.id == c.id { current = chats.first } }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(T.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(T.borderSoft, lineWidth: 1))
        .confirmationDialog("Clear all chats?", isPresented: $showClearAll, titleVisibility: .visible) {
            Button("Delete All Chats", role: .destructive) {
                for c in chats { modelContext.delete(c) }
                try? modelContext.save(); current = nil
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    @State private var showClearAll = false

    private func relative(_ date: Date) -> String {
        let secs = max(1, Int(Date().timeIntervalSince(date)))
        if secs < 3600 { return "\(secs/60)m" }
        let hrs = secs / 3600
        if hrs < 48 { return "\(hrs)h" }
        let days = hrs / 24
        if days < 14 { return "\(days)d" }
        return "\(days/7)w"
    }

    private var filteredAndSortedChats: [Chat] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? chats : chats.filter { ($0.title.lowercased().contains(q)) }
        return filtered.sorted { (a, b) in (a.isPinned == b.isPinned) ? (a.createdAt > b.createdAt) : (a.isPinned && !b.isPinned) }
    }
}

// MARK: - Placeholder Views
private struct NotesPlaceholderView: View {
    @Environment(\.tokens) private var T
    var body: some View {
        VStack(spacing: 12) {
            Text("🚧 Under construction")
                .font(.headline)
                .foregroundStyle(T.text)
            Text("Notes will arrive soon.")
                .foregroundStyle(T.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
private struct MediaPlaceholderView: View {
    @Environment(\.tokens) private var T
    var body: some View {
        VStack(spacing: 12) {
            Text("🚧 Under construction")
                .font(.headline)
                .foregroundStyle(T.text)
            Text("Media gallery will arrive soon.")
                .foregroundStyle(T.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Haptics helper (local)
private enum Haptics {
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare(); gen.selectionChanged()
    }
}
