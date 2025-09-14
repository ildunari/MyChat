import SwiftUI
import UIKit
import SwiftData

struct ContentView: View {
    @Environment(\.tokens) private var T
    @Environment(SettingsStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    
    @State private var showingSettings = false
    @State private var chatHistoryExpanded = true
    @State private var agentsExpanded = true
    private enum SectionKind: Hashable { case chats, agents }
    @State private var sectionOrder: [SectionKind] = [.chats, .agents]
    @State private var dragOffsets: [SectionKind: CGFloat] = [:]
    private let orderDefaultsKey = "home.sectionOrder"
    @State private var renamingChat: Chat? = nil
    @State private var newChatTitle: String = ""
    @State private var navNewChat: Chat? = nil
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cap = max(220, proxy.size.height * 0.33)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(sectionOrder, id: \.self) { kind in
                            let offsetY = dragOffsets[kind] ?? 0
                            SectionContainer(
                                title: kind == .chats ? "Chat History" : "Agents",
                                count: kind == .chats ? chats.count : 0,
                                isExpanded: kind == .chats ? $chatHistoryExpanded : $agentsExpanded,
                                maxHeight: cap,
                                draggedOffset: offsetY,
                                onDragChanged: { value in
                                    let dy = value.translation.height
                                    dragOffsets[kind] = dy
                                    let threshold: CGFloat = 40
                                    if dy < -threshold, let idx = sectionOrder.firstIndex(of: kind), idx > 0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            sectionOrder.swapAt(idx, idx-1)
                                            Haptics.selection()
                                        }
                                        dragOffsets[kind] = 0
                                    } else if dy > threshold, let idx = sectionOrder.firstIndex(of: kind), idx < sectionOrder.count-1 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            sectionOrder.swapAt(idx, idx+1)
                                            Haptics.selection()
                                        }
                                        dragOffsets[kind] = 0
                                    }
                                },
                                onDragEnded: { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        dragOffsets[kind] = 0
                                    }
                                }
                            ) {
                                if kind == .chats {
                                    ChatHistoryGrid(maxHeight: cap)
                                } else {
                                    AgentsPlaceholder()
                                }
                            }
                            .offset(y: offsetY)
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ComposeButton { createAndNavigate() }
                    .padding(.trailing, 2)
            }
        }
        .navigationDestination(item: $navNewChat) { chat in
            ChatView(chat: chat)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Rename Chat", isPresented: .constant(renamingChat != nil)) {
            TextField("Chat title", text: $newChatTitle)
            Button("Cancel") {
                renamingChat = nil
                newChatTitle = ""
            }
            Button("Save") {
                if let chat = renamingChat {
                    chat.title = newChatTitle.isEmpty ? "New Chat" : newChatTitle
                    try? modelContext.save()
                }
                renamingChat = nil
                newChatTitle = ""
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear { loadOrderFromStore() }
        .onChange(of: sectionOrder) { _, _ in saveOrderToStore() }
        .onChange(of: chatHistoryExpanded) { _, newVal in store.homeChatsExpanded = newVal; store.save() }
        .onChange(of: agentsExpanded) { _, newVal in store.homeAgentsExpanded = newVal; store.save() }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func ChatHistoryGrid(maxHeight cap: CGFloat) -> some View {
        if chats.isEmpty {
            EmptyStateView(message: "No chats yet. Tap the + button to start your first conversation!") {
                createAndNavigate()
            }
        } else {
            let gridSpacing: CGFloat = 12
            let verticalPad: CGFloat = 8
            let cardH = max(120, (cap - gridSpacing - verticalPad) / 2)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(chats.prefix(4)) { chat in
                    ChatCard(chat: chat, fixedHeight: cardH) {
                        renamingChat = chat
                        newChatTitle = chat.title
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func AgentsPlaceholder() -> some View {
        VStack(spacing: 16) {
            AppIcon.agent(32)
                .foregroundStyle(T.textSecondary)
            
            Text("Coming soon")
                .font(.headline)
                .foregroundStyle(T.text)
            
            Text("AI agents will help automate your workflows")
                .font(.subheadline)
                .foregroundStyle(T.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(T.surface)
        .overlay(
            RoundedRectangle(cornerRadius: T.radiusMedium)
                .stroke(T.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: T.radiusMedium))
    }
    
    @ViewBuilder
    private func ComposeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(T.accent)
                AppIcon.plus(16).foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: T.shadow, radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel("Compose New Chat")
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func SettingsHandle() -> some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(T.textSecondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.bottom, 8)
            
            // Invisible tap area
            Rectangle()
                .fill(Color.clear)
                .frame(height: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingSettings = true
        }
        .padding(.bottom, 8)
    }
    
    private func createAndNavigate() {
        let newChat = Chat(title: "New Chat")
        modelContext.insert(newChat)
        try? modelContext.save()
        navNewChat = newChat
    }
}

// MARK: - Home Section

struct HomeSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let itemCount: Int
    let maxHeight: CGFloat?
    @ViewBuilder let content: Content
    
    @Environment(\.tokens) private var T
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(T.text)
                
                Spacer()
                
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.caption)
                        .foregroundStyle(T.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(T.surface, in: Capsule())
                }
                
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Group {
                        if isExpanded {
                            AppIcon.chevronUp()
                        } else {
                            AppIcon.chevronDown()
                        }
                    }
                    .foregroundStyle(T.textSecondary)
                    .frame(width: 24, height: 24)
                }
            }
            
            // Section content
            if isExpanded {
                if let maxH = maxHeight {
                    content.frame(height: maxH).clipped()
                } else {
                    content.frame(maxHeight: 220).clipped()
                }
            }
        }
    }
}

// Draggable container with grab handle and collapse behavior
private struct SectionContainer<Content: View>: View {
    @Environment(\.tokens) private var T
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    let maxHeight: CGFloat
    let draggedOffset: CGFloat
    var onDragChanged: (DragGesture.Value) -> Void
    var onDragEnded: (DragGesture.Value) -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                AppIcon.grabber(14).foregroundStyle(T.textSecondary)
                    .gesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .global)
                            .onChanged(onDragChanged)
                            .onEnded(onDragEnded)
                    )
                Text(title).font(.title3.bold()).foregroundStyle(T.text)
                Spacer()
                if count > 0 { Text("\(count)").font(.caption).foregroundStyle(T.textSecondary).padding(.horizontal,8).padding(.vertical,4).background(T.surface, in: Capsule()) }
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Group { if isExpanded { AppIcon.chevronUp(12) } else { AppIcon.chevronDown(12) } }
                        .foregroundStyle(T.textSecondary)
                }
                .buttonStyle(.plain)
            }
            if isExpanded {
                content()
                    .frame(height: maxHeight)
                    .clipped()
            }
        }
        .scaleEffect(abs(draggedOffset) > 2 ? 1.02 : 1)
        .shadow(color: T.shadow.opacity(abs(draggedOffset) > 2 ? 0.25 : 0), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Haptics helper
private enum Haptics {
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare(); gen.selectionChanged()
    }
}

// MARK: - Persistence of section order
private extension ContentView {
    func saveOrderToStore() {
        store.homeSectionOrder = sectionOrder.map { $0 == .chats ? "chats" : "agents" }
        store.save()
    }
    func loadOrderFromStore() {
        let arr = store.homeSectionOrder
        var out: [SectionKind] = []
        for s in arr {
            if s == "chats" { out.append(.chats) }
            else if s == "agents" { out.append(.agents) }
        }
        if out.isEmpty == false { sectionOrder = out }
        chatHistoryExpanded = store.homeChatsExpanded
        agentsExpanded = store.homeAgentsExpanded
    }
}

// MARK: - Chat Card

struct ChatCard: View {
    let chat: Chat
    var fixedHeight: CGFloat? = nil
    let onRename: () -> Void

    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    
    private var lastMessage: Message? {
        chat.messages.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    private var contentTypes: [String] {
        let types = Set(chat.messages.compactMap { message in
            // Simple heuristic to detect content types
            let content = message.content.lowercased()
            if content.contains("image") || content.contains("photo") {
                return "image"
            } else if content.contains("code") || content.contains("```") {
                return "code"
            } else if content.contains("file") || content.contains("document") {
                return "file"
            } else {
                return "text"
            }
        })
        return Array(types).sorted()
    }
    
    private var ageText: String {
        let now = Date()
        let interval = now.timeIntervalSince(chat.createdAt)
        
        if interval < 3600 { // Less than 1 hour
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 { // Less than 1 day
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
    
    private var lastUsedText: String {
        guard let lastMsg = lastMessage else { return "Never" }
        let now = Date()
        let interval = now.timeIntervalSince(lastMsg.createdAt)
        
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    var body: some View {
        NavigationLink(destination: ChatView(chat: chat)) {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(chat.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(T.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Action panel with content-type icons (max 4)
                HStack(spacing: 10) {
                    ForEach(contentTypes.prefix(4), id: \.self) { type in
                        contentTypeIcon(for: type)
                            .foregroundStyle(T.accent)
                            .frame(width: 28, height: 28)
                            .background(T.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(T.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(T.borderSoft, lineWidth: 1)
                        )
                )
                
                // Metadata chips
                HStack {
                    MetadataChip(text: ageText)
                    MetadataChip(text: lastUsedText)
                    Spacer()
                }
            }
            .padding(16)
            .frame(height: fixedHeight ?? 140)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: T.radiusLarge, style: .continuous)
                    .fill(LinearGradient(colors: [T.surface, T.surfaceElevated], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: T.radiusLarge, style: .continuous).stroke(T.borderSoft, lineWidth: 1))
                    .shadow(color: T.shadow.opacity(0.25), radius: (scheme == .dark ? 4 : 6), x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Open") {
                // Navigation is handled by NavigationLink
            }
            
            Button("Rename") {
                onRename()
            }
            
            Button("Parameters") {
                // TODO: Show chat parameters
            }
            
            Button("Add to Project") {
                // TODO: Add to project functionality
            }
            
            Button("Share") {
                // TODO: Share functionality
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                deleteChat()
            }
        }
    }
    
    @ViewBuilder
    private func contentTypeIcon(for type: String) -> some View {
        switch type {
        case "image":
            AppIcon.image(14)
        case "code":
            AppIcon.code(14)
        case "file":
            AppIcon.file(14)
        default:
            AppIcon.text(14)
        }
    }
    
    private func deleteChat() {
        modelContext.delete(chat)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct MetadataChip: View {
    let text: String
    
    @Environment(\.tokens) private var T
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(T.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(T.borderSoft.opacity(0.5), in: Capsule())
    }
}

struct EmptyStateView: View {
    let message: String
    var onTap: (() -> Void)? = nil

    @Environment(\.tokens) private var T

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 16) {
                AppIcon.plus(40)
                    .foregroundStyle(T.textSecondary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(T.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(T.surface.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: T.radiusMedium)
                    .strokeBorder(T.borderSoft, style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
            )
            .clipShape(RoundedRectangle(cornerRadius: T.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new chat")
    }
}

// MARK: - Previews

#Preview("ContentView") {
    let container = try! ModelContainer(for: Chat.self, Message.self, AppSettings.self, configurations: 
        ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // Add sample data
    let sampleChat1 = Chat(title: "SwiftUI Best Practices", createdAt: Date().addingTimeInterval(-3600))
    let sampleChat2 = Chat(title: "Machine Learning Discussion", createdAt: Date().addingTimeInterval(-7200))
    
    container.mainContext.insert(sampleChat1)
    container.mainContext.insert(sampleChat2)
    
    // Add sample messages
    let msg1 = Message(role: "user", content: "How do I implement a custom SwiftUI view?", chat: sampleChat1)
    let msg2 = Message(role: "assistant", content: "Here's how to create a custom SwiftUI view with proper state management...", chat: sampleChat1)
    
    container.mainContext.insert(msg1)
    container.mainContext.insert(msg2)
    
    return ContentView()
        .modelContainer(container)
        .environment(\.tokens, ThemeFactory.make(style: .terracotta, colorScheme: .light))
}

#Preview("Empty State") {
    let container = try! ModelContainer(for: Chat.self, Message.self, AppSettings.self, configurations: 
        ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return ContentView()
        .modelContainer(container)
        .environment(\.tokens, ThemeFactory.make(style: .coolSlate, colorScheme: .dark))
}
