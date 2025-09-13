//
//  ButtonStyles.swift
//  NoteChat UIPlayground
//
//  Experiment with different button styles and animations
//

import SwiftUI

struct ButtonStylesPlayground: View {
    @State private var isPressed = false
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Button Styles Playground")
                    .font(.title)
                    .bold()
                
                // Custom Gradient Button
                Button(action: {}) {
                    Text("Gradient Button")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                
                // Neumorphic Button
                Button(action: {}) {
                    Text("Neumorphic")
                        .padding()
                        .frame(width: 200)
                }
                .buttonStyle(NeumorphicButtonStyle())
                
                // Loading Button
                Button(action: {
                    withAnimation {
                        isLoading.toggle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(isLoading ? "Loading..." : "Upload")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 150)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
                
                // Animated Scale Button
                Button(action: {}) {
                    Text("Tap Me!")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                    pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = pressing
                        }
                    },
                    perform: {})
                
                // Icon Button Row
                HStack(spacing: 20) {
                    ForEach(["heart.fill", "star.fill", "bell.fill", "bookmark.fill"], id: \.self) { icon in
                        Button(action: {}) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// Custom Button Style
struct NeumorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                Group {
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .shadow(color: .gray.opacity(0.4), radius: 5, x: 5, y: 5)
                            .shadow(color: .white, radius: 5, x: -5, y: -5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Button Styles") {
    ButtonStylesPlayground()
}

#Preview("Dark Mode") {
    ButtonStylesPlayground()
        .preferredColorScheme(.dark)
}