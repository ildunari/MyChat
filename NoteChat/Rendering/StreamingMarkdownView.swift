import SwiftUI
import MarkdownUI
#if canImport(UIKit)
import UIKit
#endif

struct StreamingMarkdownView: View {
    var snapshot: StreamingMarkdownSnapshot
    var isStreaming: Bool

    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if snapshot.stableMarkdown.isEmpty == false {
                Markdown(snapshot.stableMarkdown)
                    .markdownTheme(MarkdownThemeFactory.chatTheme(tokens: tokens, colorScheme: colorScheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if snapshot.tailRaw.isEmpty == false {
                TailBlockView(raw: snapshot.tailRaw,
                              state: snapshot.tailState,
                              tokens: tokens,
                              colorScheme: colorScheme)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transaction { transaction in
            if isStreaming {
                transaction.disablesAnimations = true
            }
        }
    }
}

/// Renders markdown content with LaTeX math support by splitting into segments
private struct MarkdownWithMath: View {
    let content: String
    let tokens: ThemeTokens
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let markdown):
                    if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Markdown(markdown)
                            .markdownTheme(MarkdownThemeFactory.chatTheme(tokens: tokens, colorScheme: colorScheme))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .inlineMath(let latex):
                    InlineMathView(latex: latex)
                case .blockMath(let latex):
                    BlockMathView(latex: latex)
                }
            }
        }
    }

    private var segments: [ContentSegment] {
        parseMarkdownWithMath(content)
    }

    private enum ContentSegment {
        case text(String)
        case inlineMath(String)
        case blockMath(String)
    }

    private func parseMarkdownWithMath(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentText = ""
        var index = text.startIndex

        while index < text.endIndex {
            // Check for block math ($$...$$)
            if text[index...].hasPrefix("$$") {
                // Flush any accumulated text
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }

                // Find closing $$
                let startIndex = text.index(index, offsetBy: 2)
                if let endRange = text[startIndex...].range(of: "$$") {
                    let latex = String(text[startIndex..<endRange.lowerBound])
                    segments.append(.blockMath(latex))
                    index = endRange.upperBound
                    continue
                } else {
                    // No closing delimiter, treat as text
                    currentText.append("$$")
                    index = startIndex
                    continue
                }
            }

            // Check for inline math ($...$)
            if text[index] == "$" {
                // Make sure it's not escaped
                let isEscaped = index > text.startIndex && text[text.index(before: index)] == "\\"
                if !isEscaped {
                    // Flush any accumulated text
                    if !currentText.isEmpty {
                        segments.append(.text(currentText))
                        currentText = ""
                    }

                    // Find closing $
                    let startIndex = text.index(after: index)
                    var searchIndex = startIndex
                    var foundClosing = false

                    while searchIndex < text.endIndex {
                        if text[searchIndex] == "$" {
                            let prevIsEscape = searchIndex > text.startIndex && text[text.index(before: searchIndex)] == "\\"
                            if !prevIsEscape {
                                let latex = String(text[startIndex..<searchIndex])
                                segments.append(.inlineMath(latex))
                                index = text.index(after: searchIndex)
                                foundClosing = true
                                break
                            }
                        }
                        searchIndex = text.index(after: searchIndex)
                    }

                    if foundClosing {
                        continue
                    } else {
                        // No closing delimiter, treat as text
                        currentText.append("$")
                        index = startIndex
                        continue
                    }
                }
            }

            currentText.append(text[index])
            index = text.index(after: index)
        }

        // Flush remaining text
        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }

        return segments
    }
}

private struct TailBlockView: View {
    let raw: String
    let state: StreamingMarkdownBuffer.TailState
    let tokens: ThemeTokens
    let colorScheme: ColorScheme

    var body: some View {
        Group {
            if state.codeFenceDelimiter != nil {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(raw)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .modifier(CodeBlockContainer(tokens: tokens, colorScheme: colorScheme))
            } else if state.isMathBlockOpen {
                Text(raw)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(tokens.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .modifier(MathTailContainer(tokens: tokens, colorScheme: colorScheme))
            } else if state.inlineMathOpen {
                // Show incomplete inline math as plain text
                Text(raw)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(tokens.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Markdown(raw)
                    .markdownTheme(MarkdownThemeFactory.chatTheme(tokens: tokens, colorScheme: colorScheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// AsyncHighlightedCodeBlock moved to MarkdownEngine for reuse

private struct MathTailContainer: ViewModifier {
    let tokens: ThemeTokens
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                    .fill(tokens.surface.opacity(colorScheme == .dark ? 0.75 : 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                    .stroke(tokens.borderSoft.opacity(0.9), lineWidth: 1)
            )
    }
}
