import SwiftUI
import SwiftData

enum MainTab: Int, CaseIterable { case chat, notes, home, media, settings }

struct RootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @State private var tab: MainTab = .home
    @Namespace private var highlightNS

    var body: some View {
        TabView(selection: $tab) {
            ContentView()
                .tag(MainTab.home)
                .tabItem { Label("Home", systemImage: "house") }

            ChatRootView()
                .tag(MainTab.chat)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.text.bubble") }

            NotesPlaceholderView()
                .tag(MainTab.notes)
                .tabItem { Label("Notes", systemImage: "note.text") }

            MediaPlaceholderView()
                .tag(MainTab.media)
                .tabItem { Label("Media", systemImage: "photo.on.rectangle") }

            SettingsView()
                .tag(MainTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .background(T.bg.ignoresSafeArea())
    }
}

// MARK: - Chat Root with left drawer

private struct ChatRootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    @State private var current: Chat? = nil
    @State private var drawerX: CGFloat = -1 // -1 closed, 0 open (as fraction of width)
    @State private var drawerOpen: Bool = false

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

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(chats) { c in
                        Button(action: { current = c; withAnimation(.spring()) { drawerX = -1 } }) {
                            HStack {
                                AppIcon.text(16).foregroundStyle(T.accent)
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
