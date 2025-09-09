// Views/ChatUI.swift
import SwiftUI

struct SuggestionChipItem: Identifiable, Hashable { let id = UUID(); let title: String; let subtitle: String }

struct SuggestionChips: View {
    let suggestions: [SuggestionChipItem]
    @Environment(\.tokens) private var T
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title)
                            .font(.subheadline.weight(.semibold))
                        Text(s.subtitle)
                            .font(.footnote)
                            .foregroundStyle(T.textSecondary)
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
            .padding(.vertical, 8) // Increased vertical padding for better spacing
        }
        .padding(.top, 8) // Add top padding to separate from chat content
        // Important: chips sit on canvas background, not input bar
        .background(T.bg)
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
    var onMic: (() -> Void)? = nil
    var onLive: (() -> Void)? = nil
    var onPlus: (() -> Void)? = nil
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.tokens) private var T

    var body: some View {
        HStack(spacing: InputMetrics.rowSpacing) {
            Button(action: { onPlus?() }) { AppIcon.plus(18) }
            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
            .background(Circle().fill(T.accentSoft))

            HStack(spacing: 8) {
                // Expanding text field
                TextField("Ask anything", text: $text, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...6)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSend() }
                    }
                    .submitLabel(.send)

                // Trailing controls (mutually exclusive)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Voice controls when input is empty (match '+' button style)
                    Button(action: { onMic?() }) {
                        AppIcon.microphone(18)
                            .foregroundStyle(T.textSecondary)
                            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
                            .background(Circle().fill(T.accentSoft))
                    }
                    Button(action: { onLive?() }) {
                        AppIcon.waveform(18)
                            .foregroundStyle(T.accent)
                            .frame(width: InputMetrics.plusSize, height: InputMetrics.plusSize)
                            .background(Circle().fill(T.accentSoft))
                    }
                } else {
                    // Send button only when there is text, styled like a small circle
                    Button(action: onSend) {
                        AppIcon.paperPlane(18)
                            .foregroundStyle(T.accent)
                            .frame(width: InputMetrics.sendSize, height: InputMetrics.sendSize)
                            .background(Circle().fill(T.accentSoft))
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
