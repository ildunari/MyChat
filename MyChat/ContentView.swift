//
//  ContentView.swift
//  ChatApp
//
//  Created by Kosta Milovanovic on 9/4/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SettingsStore.self) private var store
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    @Query private var settingsQuery: [AppSettings]
    @State private var showingSettings = false
    @State private var initialChat: Chat? = nil
    @State private var showInitialChat = false

    var body: some View {
        let tokens = resolvedTokens()
        NavigationStack {
            List {
                ForEach(chats) { chat in
                    NavigationLink {
                        ChatView(chat: chat)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title.isEmpty ? "New Chat" : chat.title)
                                .font(.headline.weight(.semibold))
                            if let last = chat.messages.sorted(by: { $0.createdAt < $1.createdAt }).last {
                                Text("\(last.role.capitalized): \(last.content)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteChat(chat)
                        } label: {
                            Label("Delete Chat", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteChats)
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { addChat() } label: { AppIcon.plus() }
                    .accessibilityLabel("New Chat")
                }
                ToolbarItem(placement: .automatic) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
            }
            .onAppear { ensureInitialChatIfNeeded() }
            .navigationDestination(isPresented: $showInitialChat) {
                if let chat = initialChat {
                    ChatView(chat: chat)
                } else {
                    EmptyView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                SettingsDockBar(title: userDisplayName(), onOpen: { showingSettings = true })
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .theme(tokens)
        .tint(tokens.accent)
        .fontDesign(fontDesignFromSettings())
        .dynamicTypeSize(dynamicTypeFromSettings())
        .preferredColorScheme(effectiveColorScheme())
        .background(tokens.bg.ignoresSafeArea())
    }

    private func addChat() {
        withAnimation {
            let chat = Chat(title: "")
            modelContext.insert(chat)
            // Persist and navigate directly into the newly created chat
            try? modelContext.save()
            initialChat = chat
            showInitialChat = true
        }
    }

    private func deleteChats(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(chats[index])
            }
        }
    }

    private func deleteChat(_ chat: Chat) {
        withAnimation {
            modelContext.delete(chat)
        }
    }

    private func ensureInitialChatIfNeeded() {
        guard chats.isEmpty, initialChat == nil else { return }
        let chat = Chat(title: "")
        modelContext.insert(chat)
        try? modelContext.save()
        initialChat = chat
        showInitialChat = true
    }
}

private extension ContentView {
    func userDisplayName() -> String {
        let uname = store.userUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uname.isEmpty { return uname }
        let first = store.userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = store.userLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "You" : full
    }

    func resolvedTokens() -> ThemeTokens {
        let paletteID = settingsQuery.first?.chatBubbleColorID ?? "coolSlate"
        let style: AppThemeStyle = {
            switch paletteID.lowercased() {
            case "slate", "coolslate": return .coolSlate
            case "sand", "sun", "sunset": return .sand
            case "lavender", "purple": return .lavender
            case "contrast", "highcontrast", "hc": return .highContrast
            default: return .coolSlate
            }
        }()
        let scheme = effectiveColorScheme() ?? colorScheme
        return ThemeFactory.make(style: style, colorScheme: scheme)
    }

    // Honor Settings → Theme: system | light | dark
    func effectiveColorScheme() -> ColorScheme? {
        switch (settingsQuery.first?.interfaceTheme ?? "system").lowercased() {
        case "light": return .light
        case "dark":  return .dark
        default:       return nil // follow system
        }
    }

    func fontDesignFromSettings() -> Font.Design {
        let v = settingsQuery.first?.interfaceFontStyle ?? "system"
        switch v {
        case "serif": return .serif
        case "rounded": return .rounded
        case "mono": return .monospaced
        default: return .default
        }
    }

    func dynamicTypeFromSettings() -> DynamicTypeSize {
        let idx = settingsQuery.first?.interfaceTextSizeIndex ?? 2
        switch idx {
        case 0: return .xSmall
        case 1: return .small
        case 2: return .medium
        case 3: return .large
        default: return .xLarge
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Chat.self, Message.self, AppSettings.self], inMemory: true)
}

// MARK: - Settings Dock (Bottom Panel)
private struct SettingsDockBar: View {
    @Environment(\.tokens) private var T
    var title: String
    var onOpen: () -> Void
    @State private var dragOffsetY: CGFloat = 0

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                AppIcon.user(20)
                    .foregroundStyle(T.accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(T.text)
                Spacer()
                AppIcon.gear(18)
                    .foregroundStyle(T.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: T.radiusLarge, style: .continuous)
                    .fill(T.surfaceElevated)
                    .shadow(color: T.shadow, radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: T.radiusLarge, style: .continuous)
                            .stroke(T.borderSoft, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Settings")
        .offset(y: dragOffsetY)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffsetY = max(-24, min(0, value.translation.height))
                }
                .onEnded { value in
                    defer { dragOffsetY = 0 }
                    if value.translation.height < -20 { onOpen() }
                }
        )
    }
}
