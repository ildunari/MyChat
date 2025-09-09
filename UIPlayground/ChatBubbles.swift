//
//  ChatBubbles.swift
//  MyChat UIPlayground
//
//  Test different chat bubble designs and animations
//

import SwiftUI

struct ChatBubblesPlayground: View {
    @State private var messageText = ""
    @State private var messages: [MockMessage] = [
        MockMessage(text: "Hey! How's it going?", isUser: false),
        MockMessage(text: "Pretty good! Just testing some UI components.", isUser: true),
        MockMessage(text: "That's awesome! SwiftUI makes it so easy to prototype.", isUser: false),
    ]
    
    var body: some View {
        VStack {
            Text("Chat Bubbles Playground")
                .font(.title2)
                .bold()
                .padding()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubbleView(message: message)
                    }
                }
                .padding()
            }
            
            // Input area
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    if !messageText.isEmpty {
                        messages.append(MockMessage(text: messageText, isUser: true))
                        messageText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            .padding()
        }
    }
}

struct MockMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatBubbleView: View {
    let message: MockMessage
    @State private var appear = false
    
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(BubbleShape(isUser: message.isUser))
                
                Text(Date(), style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .scaleEffect(appear ? 1 : 0.5)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.3), value: appear)
            .onAppear { appear = true }
            
            if !message.isUser { Spacer(minLength: 50) }
        }
    }
    
    @ViewBuilder
    var bubbleBackground: some View {
        if message.isUser {
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.gray.opacity(0.2)
        }
    }
}

struct BubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

#Preview("Chat Bubbles") {
    ChatBubblesPlayground()
}

#Preview("Dark Mode") {
    ChatBubblesPlayground()
        .preferredColorScheme(.dark)
}