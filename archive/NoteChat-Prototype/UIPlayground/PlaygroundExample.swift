//
//  PlaygroundExample.swift
//  NoteChat UIPlayground
//
//  This is a template for testing UI components in isolation.
//  Use the Canvas preview to see live updates as you code!
//

import SwiftUI

// MARK: - Test Component
struct PlaygroundExample: View {
    @State private var text = "Hello, Playground!"
    @State private var isToggled = false
    @State private var sliderValue = 0.5
    
    var body: some View {
        VStack(spacing: 20) {
            Text("UI Component Playground")
                .font(.largeTitle)
                .bold()
            
            Divider()
            
            // Test your UI components here
            VStack(alignment: .leading, spacing: 15) {
                TextField("Enter text", text: $text)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Sample Toggle", isOn: $isToggled)
                
                HStack {
                    Text("Slider:")
                    Slider(value: $sliderValue)
                    Text("\(sliderValue, specifier: "%.2f")")
                        .monospacedDigit()
                }
                
                Button(action: {
                    print("Button tapped!")
                }) {
                    Label("Test Button", systemImage: "star.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Provider
#Preview("Playground Example") {
    PlaygroundExample()
}

// MARK: - Multiple Preview Configurations
#Preview("Dark Mode", traits: .fixedLayout(width: 400, height: 600)) {
    PlaygroundExample()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - iPhone", traits: .sizeThatFitsLayout) {
    PlaygroundExample()
        .preferredColorScheme(.light)
}