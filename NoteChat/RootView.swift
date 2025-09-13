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
                // Liquid glass composer with enhanced vibrancy
                if tab == .chat {
                    InputBar(text: $chatBridge.text,
                             onSend: { chatBridge.onSend?() },
                             isStreaming: chatBridge.isStreaming,
                             onStop: { chatBridge.onStop?() },
                             onMic: { chatBridge.onMic?() },
                             onLive: { chatBridge.onLive?() },
                             onPlus: { chatBridge.onPlus?() })
                    .liquidGlass(.regular, cornerRadius: 20)
                    .shadow(color: Color.black.opacity(0.2), radius: 15, y: 5)
                    .padding(.horizontal)
                    .padding(.bottom, DockMetrics.height + 6) // sit above dock
                    .zIndex(1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Binding var selected: MainTab
    var highlightNS: Namespace.ID
    @State private var hoveredTab: MainTab? = nil

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
        HStack(spacing: 4) {
            ForEach(items, id: \.tab) { it in
                Button(action: { 
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { 
                        selected = it.tab 
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            // Liquid glass selection indicator
                            if selected == it.tab {
                                LiquidGlassTabIndicator(isSelected: true)
                                    .matchedGeometryEffect(id: "tabSelection", in: highlightNS)
                                    .frame(width: 68, height: 52)
                            }
                            
                            // Hover effect
                            if hoveredTab == it.tab && selected != it.tab {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Material.ultraThinMaterial)
                                    .frame(width: 68, height: 52)
                                    .opacity(0.5)
                            }
                            
                            VStack(spacing: 3) {
                                it.icon
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                                    .scaleEffect(selected == it.tab ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: selected)
                                Text(it.title)
                                    .font(.caption.weight(selected == it.tab ? .bold : .semibold))
                                    .foregroundStyle(selected == it.tab ? Color.white : T.textSecondary)
                            }
                            .frame(width: 76, height: 56)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredTab = hovering ? it.tab : nil
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background {
            if reduceTransparency {
                // Accessibility fallback
                RoundedRectangle(cornerRadius: 0)
                    .fill(T.surface)
                    .overlay(
                        Rectangle().fill(T.borderSoft).frame(height: 0.5), alignment: .top
                    )
            } else {
                // Liquid glass dock with vibrancy
                ZStack {
                    // Base glass material
                    Rectangle()
                        .fill(Material.regularMaterial)
                    
                    // Gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.05 : 0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Top border with glass effect
                    VStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(scheme == .dark ? 0.2 : 0.3),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .compositingGroup()
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: -5)
            }
        }
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
            // Liquid glass header
            HStack {
                Text("History")
                    .font(.headline)
                    .foregroundStyle(T.text)
                Spacer()
                Button(role: .destructive, action: { showClearAll.toggle() }) {
                    HStack(spacing: 6) { 
                        AppIcon.trash(14)
                        Text("Clear All") 
                    }
                }
                .buttonStyle(.liquidGlass(.subtle, cornerRadius: 8))
                .tint(Color.red)
                
                Button(action: { withAnimation(.spring()) { drawerX = -1 } }) { 
                    AppIcon.close(16)
                        .foregroundStyle(T.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Material.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [T.borderSoft, Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 1),
                alignment: .bottom
            )

            // Liquid glass search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search chats", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button(action: { search = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass(.subtle, cornerRadius: 10)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAndSortedChats) { c in
                        Button(action: { 
                            current = c
                            withAnimation(.spring()) { drawerX = -1 } 
                        }) {
                            HStack {
                                // Animated icon
                                Group {
                                    if c.isPinned { 
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(T.accent)
                                            .scaleEffect(1.1)
                                    } else { 
                                        AppIcon.text(16)
                                            .foregroundStyle(T.accent.opacity(0.8))
                                    }
                                }
                                .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title.isEmpty ? "New Chat" : c.title)
                                        .foregroundStyle(T.text)
                                        .lineLimit(1)
                                        .font(.system(.body, design: .rounded))
                                    
                                    Text(relative(c.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(T.textSecondary)
                                }
                                
                                Spacer()
                                
                                // Selection indicator
                                if current?.id == c.id {
                                    Circle()
                                        .fill(T.accent)
                                        .frame(width: 6, height: 6)
                                        .transition(.scale)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .liquidGlass(
                                current?.id == c.id ? .regular : .subtle,
                                cornerRadius: 12,
                                isInteractive: true
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(c.isPinned ? "Unpin" : "Pin") { 
                                withAnimation(.spring()) {
                                    c.isPinned.toggle()
                                }
                                try? modelContext.save() 
                            }
                            Divider()
                            Button("Rename") {
                                // TODO: Add rename functionality
                            }
                            Divider()
                            Button("Delete", role: .destructive) { 
                                withAnimation(.easeOut(duration: 0.2)) {
                                    modelContext.delete(c)
                                    try? modelContext.save()
                                    if current?.id == c.id { 
                                        current = chats.first 
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Material.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 1
                )
        )
        .confirmationDialog("Clear all chats?", isPresented: $showClearAll, titleVisibility: .visible) {
            Button("Delete All Chats", role: .destructive) {
                withAnimation(.easeOut(duration: 0.3)) {
                    for c in chats { modelContext.delete(c) }
                    try? modelContext.save()
                    current = nil
                }
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
