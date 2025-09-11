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
        @Environment(SettingsStore.self) private var store
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
        @State private var showingSettings = false
    @State private var initialChat: Chat? = nil
    @State private var showInitialChat = false

    var body: some View {
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

}

#Preview {
    if let container = try? ModelContainer(
        for: Chat.self, Message.self, AppSettings.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        let settings = SettingsStore(context: container.mainContext)
        return AppThemeView {
            ContentView()
        }
        .environment(settings)
        .modelContainer(container)
    } else {
        return Text("Preview unavailable")
    }
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
