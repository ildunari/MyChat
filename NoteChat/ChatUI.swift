// Views/ChatUI.swift
import SwiftUI

struct SuggestionChipItem: Identifiable, Hashable { let id = UUID(); let title: String; let subtitle: String }

// Old horizontal chips (no longer used in Chat); keeping for possible reuse.
struct SuggestionChips: View {
    let suggestions: [SuggestionChipItem]
    @Environment(\.tokens) private var T
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.subheadline.weight(.semibold))
                        Text(s.subtitle).font(.footnote).foregroundStyle(T.textSecondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(T.accentSoft)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(T.borderSoft))
                            .shadow(color: T.shadow.opacity(0.12), radius: 6, y: 2)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(T.bg)
    }
}

// Centered starter card grid (2x2) for empty chats
struct StarterCardGrid: View {
    let suggestions: [SuggestionChipItem]
    var onPick: (SuggestionChipItem) -> Void
    @Environment(\.tokens) private var T
    private var gridItems: [GridItem] { 
        [GridItem(.flexible(), spacing: 20), 
         GridItem(.flexible(), spacing: 20)] 
    }
    var body: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: gridItems, alignment: .center, spacing: 20) {
                ForEach(Array(suggestions.prefix(4))) { s in
                    Button(action: { onPick(s) }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(T.text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Text(s.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(T.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .padding(18)
                        .background(
                            Group {
                                if #available(iOS 18.0, *) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.regularMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: T.shadow.opacity(0.08), radius: 12, x: 0, y: 4)
                                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(T.surfaceElevated)
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(T.borderSoft))
                                        .shadow(color: T.shadow.opacity(0.12), radius: 8, y: 3)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: suggestions)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

private enum InputMetrics { // precise sizing
    static let edgePadding: CGFloat = 16
    static let rowSpacing: CGFloat = 10
    static let plusSize: CGFloat = 40
    static let fieldHeight: CGFloat = 40
    static let fieldCorner: CGFloat = 18
    static let sendSize: CGFloat = 40 // match plusSize for visual consistency
}

struct InputBar: View {
    @Binding var text: String
    var onSend: () -> Void
    // While streaming, show a Stop button instead of Send
    var isStreaming: Bool = false
    var onStop: (() -> Void)? = nil
    var onMic: (() -> Void)? = nil
    var onLive: (() -> Void)? = nil
    var onPlus: (() -> Void)? = nil
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.tokens) private var T
    @Environment(SettingsStore.self) private var store

    var body: some View {
        HStack(spacing: InputMetrics.rowSpacing) {
            Button(action: { onPlus?() }) { AppIcon.plus(18) }
            .accessibilityLabel("Attachments")
            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
            .background(Circle().fill(T.accentSoft))

            HStack(spacing: 8) {
                // Expanding text field
                TextField("Ask anything", text: $text, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .lineLimit(1...6)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        // Enter-to-send behavior is controlled by Settings
                        if store.enterToSend, !isStreaming, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSend() }
                    }
                    .submitLabel(.send)

                // Trailing controls (mutually exclusive)
                if isStreaming {
                    // Stop streaming button
                    Button(action: { onStop?() }) {
                        AppIcon.stop(18)
                            .foregroundStyle(.red)
                            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
                            .background(Circle().fill(Color.red.opacity(0.15)))
                    }
                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Voice controls when input is empty (match '+' button style)
                    Button(action: { onMic?() }) {
                        AppIcon.microphone(18)
                            .foregroundStyle(T.textSecondary)
                            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
                            .background(Circle().fill(T.accentSoft))
                    }
                    .accessibilityLabel("Voice input")
                    Button(action: { onLive?() }) {
                        AppIcon.waveform(18)
                            .foregroundStyle(T.accent)
                            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
                            .background(Circle().fill(T.accentSoft))
                    }
                    .accessibilityLabel("Live mode")
                } else {
                    // Send button only when there is text, styled like a small circle
                    Button(action: { if !isStreaming { onSend() } }) {
                        AppIcon.paperPlane(18)
                            .foregroundStyle(T.accent)
                            .frame(width: InputMetrics.sendSize, height: InputMetrics.sendSize)
                            .background(Circle().fill(T.accentSoft))
                    }
                    .accessibilityLabel("Send")
                    .contextMenu {
                        if !isStreaming {
                            Button("Send") { onSend() }
                            Button("Insert New Line") { text.append("\n") }
                        } else {
                            Button("Stop", role: .destructive) { onStop?() }
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minHeight: InputMetrics.fieldHeight) // compact baseline size
            .padding(.horizontal, 12)
            .padding(.vertical, 6) // slight vertical padding so text never looks cut off
            .background(
                RoundedRectangle(cornerRadius: InputMetrics.fieldCorner, style: .continuous)
                    .fill(T.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: InputMetrics.fieldCorner, style: .continuous)
                            .stroke(isTextFieldFocused ? T.accent : T.borderSoft, lineWidth: isTextFieldFocused ? 1.2 : 1)
                    )
            )
        }
        .padding(.horizontal, InputMetrics.edgePadding)
        .padding(.bottom, 8)
    }
}
