import SwiftUI
import SwiftData

/// Chat history sidebar with full-featured list: long-press to rename, delete, or favorite
struct ChatHistorySidebar: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]
    
    var currentChatID: UUID?
    @Binding var isPresented: Bool
    var onSelectChat: (Chat) -> Void
    var onDeleteChat: ((Chat) -> Void)? = nil
    
    @State private var renamingChatID: UUID? = nil
    @State private var newTitle: String = ""
    @State private var searchText: String = ""
    
    private var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chats
        }
        return chats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    AppIcon.close(20)
                        .foregroundStyle(T.text)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(T.surface.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)

                Text("Chat History")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(T.text)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Search bar
            HStack(spacing: 12) {
                AppIcon.search(16)
                    .foregroundStyle(T.textSecondary)

                TextField("Search chats", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(T.text)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        AppIcon.close(14)
                            .foregroundStyle(T.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(T.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(T.borderSoft.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Chat list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredChats) { chat in
                        ChatHistoryRow(chat: chat,
                                       isSelected: chat.id == currentChatID,
                                       onTap: {
                            onSelectChat(chat)
                            withAnimation(.easeOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }, onRename: {
                            renamingChatID = chat.id
                            newTitle = chat.title
                        }, onDelete: {
                            deleteChat(chat)
                        }, onToggleFavorite: {
                            toggleFavorite(chat)
                        })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .alert("Rename Chat", isPresented: Binding(
            get: { renamingChatID != nil },
            set: { if !$0 { renamingChatID = nil; newTitle = "" } }
        )) {
            TextField("Chat title", text: $newTitle)
            Button("Cancel", role: .cancel) {
                renamingChatID = nil
                newTitle = ""
            }
            Button("Save") {
                if let chatID = renamingChatID,
                   let chat = chats.first(where: { $0.id == chatID }) {
                    chat.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Chat" : newTitle
                    try? modelContext.save()
                }
                renamingChatID = nil
                newTitle = ""
            }
        }
    }
    
    private func deleteChat(_ chat: Chat) {
        let wasActive = chat.id == currentChatID
        modelContext.delete(chat)
        try? modelContext.save()
        if wasActive {
            onDeleteChat?(chat)
        }
    }
    
    private func toggleFavorite(_ chat: Chat) {
        chat.isFavorite.toggle()
        try? modelContext.save()
    }
}

/// Individual row in the chat history list
struct ChatHistoryRow: View {
    @Environment(\.tokens) private var T
    let chat: Chat
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    
    private var lastMessage: Message? {
        chat.messages.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: chat.createdAt, relativeTo: Date())
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: chat.createdAt)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(T.text)
                            .lineLimit(1)
                        
                        if let lastMsg = lastMessage {
                            Text(lastMsg.content)
                                .font(.caption)
                                .foregroundStyle(T.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if chat.isFavorite {
                            AppIcon.star(12, filled: true)
                                .foregroundStyle(T.accent)
                        }
                        
                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundStyle(T.textSecondary)
                        
                        Text(formattedTime)
                            .font(.caption2)
                            .foregroundStyle(T.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? T.surfaceElevated.opacity(0.92) : T.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(chat.isFavorite ? "Unfavorite" : "Favorite", systemImage: chat.isFavorite ? "star.slash" : "star")
            }
            
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private extension ChatHistoryRow {
    var borderColor: Color {
        if isSelected { return T.accent }
        if chat.isFavorite { return T.accent.opacity(0.3) }
        return T.borderSoft
    }
}
