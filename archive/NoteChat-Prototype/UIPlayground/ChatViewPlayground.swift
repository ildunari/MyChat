//
//  ChatViewPlayground.swift
//  NoteChat UIPlayground
//
//  Test and iterate on the main chat interface
//

import SwiftUI
import SwiftData
import Observation

// MARK: - Mock Data
struct MockMessage {
    let id = UUID()
    let role: String
    let content: String
    let timestamp = Date()
    let isStreaming: Bool = false
}

@Observable
class MockChat {
    let id = UUID()
    var title: String
    var messages: [MockMessage]
    var isWaitingForResponse = false
    var streamingContent = ""
    
    init(title: String, messages: [MockMessage] = []) {
        self.title = title
        self.messages = messages
    }
}

// MARK: - Simplified Chat View for Testing
struct ChatViewPlayground: View {
    @State private var chat = MockChat(
        title: "Test Conversation",
        messages: [
            MockMessage(role: "user", content: "Hello! Can you help me understand SwiftUI?"),
            MockMessage(role: "assistant", content: "Of course! SwiftUI is Apple's modern declarative framework for building user interfaces. What would you like to know?"),
            MockMessage(role: "user", content: "How do I create custom views?"),
            MockMessage(role: "assistant", content: "Creating custom views in SwiftUI is straightforward:\n\n1. **Define a struct** that conforms to `View`\n2. **Implement the body property**\n3. **Return your view hierarchy**\n\n```swift\nstruct MyCustomView: View {\n    var body: some View {\n        Text(\"Hello, World!\")\n    }\n}\n```")
        ]
    )
    
    @State private var messageText = ""
    @State private var isShowingSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            chatHeader
            
            Divider()
            
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(chat.messages.enumerated()), id: \.1.id) { index, message in
                            MessageBubble(
                                message: message,
                                isLastMessage: index == chat.messages.count - 1
                            )
                            .id(message.id)
                        }
                        
                        if chat.isWaitingForResponse {
                            ThinkingIndicator()
                        }
                        
                        if !chat.streamingContent.isEmpty {
                            StreamingBubble(content: chat.streamingContent)
                        }
                    }
                    .padding()
                }
                .onChange(of: chat.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(chat.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input Area
            inputArea
        }
    }
    
    var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title)
                    .font(.headline)
                Text("\(chat.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { isShowingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? .gray : .accentColor)
            }
            .disabled(messageText.isEmpty || chat.isWaitingForResponse)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let newMessage = MockMessage(role: "user", content: messageText)
        chat.messages.append(newMessage)
        messageText = ""
        
        // Simulate AI response
        chat.isWaitingForResponse = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            chat.isWaitingForResponse = false
            chat.streamingContent = "I'm thinking about your question"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chat.streamingContent += " and formulating a response..."
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let response = MockMessage(
                        role: "assistant",
                        content: "This is a simulated response to test the UI. You can modify this playground to test different layouts, animations, and interactions!"
                    )
                    chat.messages.append(response)
                    chat.streamingContent = ""
                }
            }
        }
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: MockMessage
    let isLastMessage: Bool
    
    var isUser: Bool { message.role == "user" }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("AI")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? Color.blue : Color(UIColor.secondarySystemFill))
                    )
                    .foregroundColor(isUser ? .white : .primary)
                    .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
                
                if isLastMessage {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            
            if isUser {
                Circle()
                    .fill(Color.green.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Streaming Bubble
struct StreamingBubble: View {
    let content: String
    @State private var showCursor = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("AI")
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            HStack(spacing: 2) {
                Text(content)
                if showCursor {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 16)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemFill))
            )
            .frame(maxWidth: 280, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                showCursor.toggle()
            }
        }
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .padding()
        .onAppear {
            animationAmount = 2
        }
    }
}

// MARK: - Preview Configurations
#Preview("Light Mode") {
    ChatViewPlayground()
}

#Preview("Dark Mode") {
    ChatViewPlayground()
        .preferredColorScheme(.dark)
}

#Preview("Empty Chat") {
    struct EmptyWrapper: View {
        @State private var chat = MockChat(title: "New Chat", messages: [])
        var body: some View {
            ChatViewPlayground()
        }
    }
    return EmptyWrapper()
}

#Preview("Long Conversation") {
    struct LongWrapper: View {
        @State private var chat = MockChat(
            title: "Extended Discussion",
            messages: (0..<20).map { i in
                MockMessage(
                    role: i % 2 == 0 ? "user" : "assistant",
                    content: "Message \(i): This is a longer message to test scrolling and performance with many messages in the conversation."
                )
            }
        )
        var body: some View {
            ChatViewPlayground()
        }
    }
    return LongWrapper()
}
