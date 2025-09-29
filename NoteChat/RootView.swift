import SwiftUI
import UIKit
import SwiftData

enum MainTab: Int, CaseIterable { case chat, notes, home, media, settings }

struct RootView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var store
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var tab: MainTab = .home
    @Namespace private var highlightNS

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            if store.useLiquidGlass {
                LiquidGlassBackground()
                    .allowsHitTesting(false)
                    .opacity(reduceTransparency ? 0 : store.liquidGlassIntensity)
            }

            TabView(selection: $tab) {
                ContentView()
                    .tag(MainTab.home)

                ChatRootView()
                    .tag(MainTab.chat)

                NotesPlaceholderView()
                    .tag(MainTab.notes)

                MediaWorkspaceView()
                    .tag(MainTab.media)

                SettingsView()
                    .tag(MainTab.settings)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                DockTabBar(selected: $tab, highlightNS: highlightNS)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(T.bg.opacity(0.4).ignoresSafeArea())
    }
}

private struct DockTabBar: View {
    @Environment(\.tokens) private var T
    @Environment(\.colorScheme) private var scheme
    @Binding var selected: MainTab
    var highlightNS: Namespace.ID

    private let items: [MainTab] = [.home, .chat, .notes, .media, .settings]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                dockButton(for: item)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(height: DockMetrics.height)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(T.borderSoft.opacity(scheme == .dark ? 0.32 : 0.55), lineWidth: 0.8)
                )
        )
        .shadow(color: T.shadow.opacity(0.25), radius: 20, y: 16)
    }

    @ViewBuilder
    private func icon(for tab: MainTab) -> some View {
        switch tab {
        case .home: AppIcon.home(20)
        case .chat: AppIcon.chat(20)
        case .notes: AppIcon.note(20)
        case .media: AppIcon.image(20)
        case .settings: AppIcon.gear(20)
        }
    }

    private func title(for tab: MainTab) -> String {
        switch tab {
        case .home: return "Home"
        case .chat: return "Chat"
        case .notes: return "Notes"
        case .media: return "Media"
        case .settings: return "Settings"
        }
    }

    @ViewBuilder
    private func dockButton(for item: MainTab) -> some View {
        let isSelected = selected == item

        Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                selected = item
            }
            Haptics.selection()
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(T.accent)
                        .matchedGeometryEffect(id: "dock_selection", in: highlightNS)
                        .frame(height: 56)
                        .shadow(color: T.shadow.opacity(0.25), radius: 14, y: 8)
                }
                VStack(spacing: 6) {
                    icon(for: item)
                        .foregroundStyle(isSelected ? T.accentOn : T.textSecondary)
                        .frame(height: 20)
                    Text(title(for: item))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? T.accentOn : T.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 12)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title(for: item))
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
        .accessibilityHint(Text("Switch to the \(title(for: item)) tab"))
    }
}

enum DockMetrics { static let height: CGFloat = 84 }

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

                drawer
                    .frame(width: maxWidth)
                    .offset(x: -maxWidth + maxWidth * max(0, drawerX))
                    .shadow(color: T.shadow.opacity(0.3), radius: 12, x: 8, y: 0)

                if drawerX > 0.01 {
                    Color.black.opacity(0.25 * drawerX)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring()) { drawerX = -1 } }
                }
                if drawerX <= -0.98 {
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
                        if v.startLocation.x < 16 || drawerX > 0 {
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
        LiquidGlassPanel(cornerRadius: 26,
                         padding: EdgeInsets(top: 16, leading: 16, bottom: 20, trailing: 16),
                         shadowRadius: 14,
                         shadowOpacity: 0.18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
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
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: { withAnimation(.spring()) { drawerX = -1 } }) {
                        AppIcon.close(14)
                            .foregroundStyle(T.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close history drawer")
                }

                Divider()
                    .overlay(T.borderSoft.opacity(0.7))

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chats) { c in
                            Button(action: { current = c; withAnimation(.spring()) { drawerX = -1 } }) {
                                HStack(alignment: .center, spacing: 12) {
                                    AppIcon.text(16)
                                        .foregroundStyle(T.accent)
                                        .frame(width: 28, height: 28)
                                        .background(T.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title.isEmpty ? "New Chat" : c.title)
                                            .foregroundStyle(T.text)
                                            .lineLimit(1)
                                        Text(relative(c.createdAt))
                                            .font(.caption)
                                            .foregroundStyle(T.textSecondary)
                                    }

                                    Spacer(minLength: 8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(T.surface.opacity(0.75))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

// MARK: - Haptics helper
private enum Haptics {
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare(); gen.selectionChanged()
    }
}
