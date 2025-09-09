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
                                .font(.headline)
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
                SettingsView(context: modelContext)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
            }
            .onAppear { ensureInitialChatIfNeeded() }
        }
        .navigationDestination(isPresented: $showInitialChat) {
            if let chat = initialChat {
                ChatView(chat: chat)
            } else {
                EmptyView()
            }
        }
        .theme(tokens)
        .fontDesign(fontDesignFromSettings())
        .dynamicTypeSize(dynamicTypeFromSettings())
        .background(tokens.bg.ignoresSafeArea())
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

private extension ContentView {
    func resolvedTokens() -> ThemeTokens {
        let paletteID = settingsQuery.first?.chatBubbleColorID ?? "terracotta"
        let style: AppThemeStyle = {
            switch paletteID.lowercased() {
            case "slate", "coolslate": return .coolSlate
            case "sand", "sun", "sunset": return .sand
            case "lavender", "purple": return .lavender
            case "contrast", "highcontrast", "hc": return .highContrast
            default: return .terracotta
            }
        }()
        return ThemeFactory.make(style: style, colorScheme: colorScheme)
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
