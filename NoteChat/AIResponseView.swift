// Views/AIResponseView.swift
import SwiftUI
import UIKit

// MarkdownUI removed in favor of Down renderer

import SwiftMath // SwiftMath provides MTMathUILabel for native LaTeX rendering

struct AIResponseView: View {
    enum Mode { case streaming, final }
    let content: String
    var mode: Mode = .final
    @Environment(\.tokens) private var T

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parseBlocks(from: content)) { block in
                switch block.kind {
                case .markdown(let text):
                    MarkdownSegment(text: text, mode: mode)
                case .code(let lang, let code):
                    CodeBlockSegment(language: lang, code: code)
                case .math(let latex):
                    MathBlockSegment(latex: latex)
                }
            }
        }
        .padding(.vertical, 2)
        .tint(T.link)
    }
}

// MARK: - Parsing

private enum BlockKind { case markdown(String), code(lang: String?, code: String), math(String) }
private struct Block: Identifiable { let id = UUID(); let kind: BlockKind }

private func parseBlocks(from text: String) -> [Block] {
    // Recognize triple‑backtick code blocks and $$ math blocks as top‑level segments.
    // Simple, linear parser; leaves inline $...$ to the Markdown engine.
    enum Token { case code(lang: String?, body: String), math(body: String), text(String) }
    var tokens: [Token] = []
    var remainder = text[...]

    func takeUntil(_ marker: String, in s: Substring) -> (Substring, Substring)? {
        guard let range = s.range(of: marker) else { return nil }
        return (s[..<range.lowerBound], s[range.upperBound...])
    }

    while !remainder.isEmpty {
        if remainder.hasPrefix("```") {
            // code block
            let afterTicks = remainder.dropFirst(3)
            let firstLineEnd = afterTicks.firstIndex(of: "\n") ?? afterTicks.endIndex
            let langStr = afterTicks[..<firstLineEnd]
            let lang = langStr.isEmpty ? nil : String(langStr)
            let afterLang = afterTicks.dropFirst(langStr.count)
            if let (body, rest) = takeUntil("```", in: afterLang) {
                // Only strip a single leading newline if present (avoid trimming first code character)
                let bodyString = body.first == "\n" ? String(body.dropFirst()) : String(body)
                tokens.append(.code(lang: lang, body: bodyString))
                remainder = rest
                continue
            } else {
                tokens.append(.text(String(remainder)))
                break
            }
        } else if remainder.hasPrefix("$$") {
            // math block
            let after = remainder.dropFirst(2)
            if let (body, rest) = takeUntil("$$", in: after) {
                tokens.append(.math(body: String(body)))
                remainder = rest
                continue
            } else {
                tokens.append(.text(String(remainder)))
                break
            }
        } else {
            // capture until next special block
            if let codeRange = remainder.range(of: "```"), let mathRange = remainder.range(of: "$$") {
                let next = min(codeRange.lowerBound, mathRange.lowerBound)
                tokens.append(.text(String(remainder[..<next])))
                remainder = remainder[next...]
            } else if let range = remainder.range(of: "```") ?? remainder.range(of: "$$") {
                tokens.append(.text(String(remainder[..<range.lowerBound])))
                remainder = remainder[range.lowerBound...]
            } else {
                tokens.append(.text(String(remainder)))
                break
            }
        }
    }

    return tokens.map { token in
        switch token {
        case .text(let t): return Block(kind: .markdown(t))
        case .code(let lang, let body): return Block(kind: .code(lang: lang, code: body.trimmingCharacters(in: .whitespacesAndNewlines)))
        case .math(let body): return Block(kind: .math(body.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }.filter { block in
        switch block.kind { case .markdown(let t): return t.isEmpty == false; default: return true }
    }
}

// MARK: - Segments

private struct MarkdownSegment: View {
    let text: String
    let mode: AIResponseView.Mode
    @Environment(\.tokens) private var T
    @State private var attributed: AttributedString? = nil
    @State private var parseTask: Task<Void, Never>? = nil

    // Lightweight detector for Markdown tables (header and pipes present)
    private var containsTable: Bool {
        text.contains("|") && text.contains("---")
    }

    var body: some View {
        Group {
            if text.contains("$") {
                InlineMathParagraph(text: text)
                    .foregroundStyle(T.text)
            } else {
                contentView
            }
        }
        .task(id: taskID) {
            // Cancel any in-flight parse
            parseTask?.cancel()
            parseTask = Task { [text, mode] in
                // Small debounce during streaming to coalesce updates
                if mode == .streaming {
                    try? await Task.sleep(nanoseconds: 120_000_000) // ~120ms
                }
                let out: AttributedString
                switch mode {
                case .streaming:
                    out = await MarkdownParser.shared.parseStreaming(text)
                case .final:
                    out = await MarkdownParser.shared.parseFinal(text, preferSystem: true)
                }
                await MainActor.run { self.attributed = out }
            }
        }
    }

    private var taskID: String { (mode == .streaming ? "s|" : "f|") + String(text.hashValue) }

    @ViewBuilder
    private var contentView: some View {
        if let a = attributed {
            if containsTable {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(a)
                        .font(.body)
                        .foregroundStyle(T.text)
                        .textSelection(.enabled)
                }
            } else {
                Text(a)
                    .font(.body)
                    .foregroundStyle(T.text)
                    .textSelection(.enabled)
            }
        } else {
            // Fallback while parsing: render a quick plaintext preview
            if containsTable {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(String(text.prefix(200)))
                        .font(.body)
                        .foregroundStyle(T.text)
                        .textSelection(.enabled)
                }
            } else {
                Text(String(text.prefix(200)))
                    .font(.body)
                    .foregroundStyle(T.text)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct CodeBlockSegment: View {
    let language: String?
    let code: String
    @Environment(\.tokens) private var T
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HighlightedCodeView(code: code, language: language)
                .padding(6)
                .background(T.codeBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(T.borderSoft, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Toolbar overlay (copy / expand)
            HStack(spacing: 6) {
                if let lang = language, lang.isEmpty == false {
                    Text(lang.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityHidden(true)
                }
                Button(action: { UIPasteboard.general.string = code }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Copy code")
                Button(action: { NotificationCenter.default.post(name: Notification.Name("ExpandResponse"), object: nil, userInfo: ["text": "```\(language ?? "")\n\(code)\n```"]) }) {
                    Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Expand code")
            }
            .padding(8)
        }
    }
}

private struct MathBlockSegment: View {
    let latex: String
    @State private var renderingFailed = false
    
    var body: some View {
        Group {
            if renderingFailed {
                // KaTeX fallback for edge cases or if SwiftMath fails
                MathWebView(latex: latex, displayMode: true)
                    .frame(minHeight: 28)
            } else {
                // Primary: Use SwiftMath's native MTMathUILabel
                SwiftMathLabel(latex: latex, displayMode: true, renderingFailed: $renderingFailed)
                    .padding(.vertical, 4)
            }
        }
    }
}

// Unified highlighted code view using CodeHighlighter actor (library-agnostic)
private struct HighlightedCodeView: UIViewRepresentable {
    let code: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme

    final class Coordinator {
        var task: Task<Void, Never>? = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.backgroundColor = UIColor.clear
        tv.font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Cancel any inflight highlight task
        context.coordinator.task?.cancel()
        uiView.attributedText = NSAttributedString(string: code, attributes: [.font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)])
        let theme = CodeTheme.current(for: colorScheme)
        context.coordinator.task = Task {
            let out = await CodeHighlighter.shared.highlight(code, lang: language, theme: theme)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                uiView.attributedText = out
                uiView.textColor = UIColor.label
            }
        }
    }
}

// SwiftMath UIViewRepresentable wrapper for MTMathUILabel
private struct SwiftMathLabel: UIViewRepresentable {
    let latex: String
    var displayMode: Bool = false
    @Binding var renderingFailed: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.labelMode = displayMode ? .display : .text
        label.textAlignment = .center
        label.font = MTFontManager().defaultFont
        return label
    }
    
    func updateUIView(_ label: MTMathUILabel, context: Context) {
        label.latex = latex
        label.textColor = colorScheme == .dark ? .white : .black
        label.labelMode = displayMode ? .display : .text
        
        // Check if rendering failed (error property is set)
        if label.error != nil {
            // Fall back to KaTeX for this equation
            renderingFailed = true
        }
    }
}

// Helper view for inline math rendering with fallback
private struct InlineMathView: View {
    let latex: String
    @State private var renderingFailed = false
    
    var body: some View {
        if renderingFailed {
            // KaTeX fallback for edge cases
            MathWebView(latex: latex, displayMode: false)
                .frame(minHeight: 22)
        } else {
            // Primary: SwiftMath native rendering
            SwiftMathLabel(latex: latex, displayMode: false, renderingFailed: $renderingFailed)
        }
    }
}

// MARK: Inline math paragraph rendering

private struct InlineMathParagraph: View {
    let text: String

    var pieces: [InlinePiece] {
        parseInlineMath(text)
    }

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, p in
                switch p {
                case .text(let t):
                    Text(t)
                case .math(let ltx):
                    InlineMathView(latex: ltx)
                }
            }
        }
    }
}

private enum InlinePiece { case text(String), math(String) }

private func parseInlineMath(_ s: String) -> [InlinePiece] {
    var out: [InlinePiece] = []
    var buffer = ""
    var i = s.startIndex
    var inMath = false
    while i < s.endIndex {
        let ch = s[i]
        if ch == "$" {
            // toggle math mode (ignore $$ which are handled as blocks earlier)
            // If next is '$', treat as literal and skip
            let nextIndex = s.index(after: i)
            if nextIndex < s.endIndex, s[nextIndex] == "$" {
                buffer.append("$$")
                i = s.index(after: nextIndex)
                continue
            }
            if inMath {
                out.append(.math(buffer))
                buffer.removeAll()
                inMath = false
            } else {
                if buffer.isEmpty == false { out.append(.text(buffer)); buffer.removeAll() }
                inMath = true
            }
            i = s.index(after: i)
            continue
        }
        buffer.append(ch)
        i = s.index(after: i)
    }
    if buffer.isEmpty == false {
        out.append(inMath ? .math(buffer) : .text(buffer))
    }
    return out
}
