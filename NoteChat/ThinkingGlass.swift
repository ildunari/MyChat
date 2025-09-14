// UI/ThinkingGlass.swift
import SwiftUI

// MARK: - Compact Bubble (tap to expand)
struct ThinkingGlassBubble: View {
    let snippet: String
    var onTap: () -> Void
    @Environment(\.tokens) private var T
    @State private var phase: Double = 0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Animated dots
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).opacity(opacity(0))
                    Circle().frame(width: 6, height: 6).opacity(opacity(1))
                    Circle().frame(width: 6, height: 6).opacity(opacity(2))
                }
                .foregroundStyle(T.accent)

                // Rolling snippet (single line)
                Text(snippet.isEmpty ? "Thinking…" : snippet)
                    .font(.footnote)
                    .foregroundStyle(T.text)
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(T.borderSoft, lineWidth: 0.7))
            .shadow(color: T.shadow.opacity(0.12), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) { phase = 1 }
        }
    }

    private func opacity(_ i: Int) -> Double { max(0.25, 1 - abs(sin(phase * .pi + Double(i) * 0.9))) }
}

// MARK: - Expanded Panel (glass menu)
struct ThinkingGlassPanel: View {
    let title: String
    @Binding var text: String
    var onClose: () -> Void
    @Environment(\.tokens) private var T
    @State private var autoscroll: Bool = true

    var body: some View {
        ZStack {
            // Glass background container
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: T.shadow.opacity(0.2), radius: 20, y: 10)

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(T.text)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(T.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(T.borderSoft)

                // Streaming content with bottom fade/blur effect
                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                // Monospaced for subtle differentiation of reasoning tokens
                                Text(text.isEmpty ? "Waiting for thinking tokens…" : text)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(T.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                // Anchor for autoscroll
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(16)
                        }
                        .onChange(of: text) { _, _ in
                            if autoscroll { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                        }
                    }

                    // Fade mask at bottom to simulate blur as content approaches edge
                    Rectangle()
                        .fill(LinearGradient(colors: [T.background.opacity(0), T.background.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                        .allowsHitTesting(false)
                }

                // Controls row
                HStack {
                    Toggle(isOn: $autoscroll) { Text("Auto‑scroll").font(.footnote) }
                        .toggleStyle(.switch)
                        .tint(T.accent)
                    Spacer()
                }
                .padding(12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Thinking panel")
    }
}

