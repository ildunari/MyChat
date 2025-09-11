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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: { AppIcon.gear() }
                        .accessibilityLabel("Settings")
                }
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
        }
    }

    private func addChat() {
        withAnimation {
            let chat = Chat(title: "")
            modelContext.insert(chat)
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
