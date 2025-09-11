import SwiftUI
import SwiftData

enum MainTab: Int, CaseIterable { case chat, notes, home, media, settings }

struct RootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @State private var tab: MainTab = .home
    @Namespace private var highlightNS

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: ContentView()
                case .chat: ChatRootView()
                case .notes: NotesPlaceholderView()
                case .media: MediaPlaceholderView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom dock bar
            DockTabBar(selected: $tab, highlightNS: highlightNS)
                .padding(.bottom, 2)
                .background(Color.clear.ignoresSafeArea(edges: .bottom))
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
                                    .frame(width: 64, height: 44)
                            }
                            HStack(spacing: 6) {
                                it.icon
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                                Text(it.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                            }
                            .frame(height: 44)
                            .padding(.horizontal, 10)
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
            Rectangle()
                .fill(T.surface)
                .shadow(color: T.shadow.opacity(0.08), radius: 10, x: 0, y: -2)
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Chat Root with left drawer

private struct ChatRootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    @State private var current: Chat? = nil
    @State private var drawerX: CGFloat = -1 // -1 closed, 0 open (as fraction of width)

    var body: some View {
        GeometryReader { geo in
            let maxWidth = geo.size.width * 0.66
            ZStack(alignment: .leading) {
                // Chat content behind
                if let chat = current ?? chats.first {
                    NavigationStack { ChatView(chat: chat) }
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
                    }
            )
            .onAppear { if current == nil { current = chats.first } }
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
            AppIcon.note(28).foregroundStyle(T.textSecondary)
            Text("Notes coming soon").foregroundStyle(T.textSecondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
private struct MediaPlaceholderView: View {
    @Environment(\.tokens) private var T
    var body: some View {
        VStack(spacing: 12) {
            AppIcon.image(28).foregroundStyle(T.textSecondary)
            Text("Media gallery coming soon").foregroundStyle(T.textSecondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
