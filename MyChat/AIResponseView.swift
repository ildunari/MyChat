// Views/AIResponseView.swift
import SwiftUI

// MarkdownUI removed in favor of Down renderer

#if canImport(Highlightr)
import Highlightr
#endif

#if canImport(SwiftMath)
import SwiftMath
#endif

struct AIResponseView: View {
    let content: String
    @Environment(\.tokens) private var T

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parseBlocks(from: content)) { block in
                switch block.kind {
                case .markdown(let text):
                    MarkdownSegment(text: text)
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
    @Environment(\.tokens) private var T

    // Lightweight detector for Markdown tables (header and pipes present)
    private var containsTable: Bool {
        text.contains("|") && text.contains("---")
    }

    var body: some View {
        Group {
            if text.contains("$") {
                // Use our inline math renderer when inline $...$ detected
                InlineMathParagraph(text: text)
                    .foregroundStyle(T.text)
            } else {
                // Down-based renderer → AttributedString → SwiftUI Text
                let attributed = renderMarkdownAttributed(text,
                                                          linkColor: T.link,
                                                          preferSystemStyling: true)
                if containsTable {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(attributed)
                            .font(.body)
                            .foregroundStyle(T.text)
                            .textSelection(.enabled)
                    }
                } else {
                    Text(attributed)
                        .font(.body)
                        .foregroundStyle(T.text)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct CodeBlockSegment: View {
    let language: String?
    let code: String
    @Environment(\.tokens) private var T
    var body: some View {
        Group {
            #if canImport(Highlightr) || canImport(Highlighter) || canImport(HighlighterSwift)
            HighlightedCodeView(code: code, language: language)
                .padding(6)
                .background(T.codeBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(T.borderSoft, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            #else
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
            }
            .background(T.codeBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(T.borderSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            #endif
        }
    }
}

private struct MathBlockSegment: View {
    let latex: String
    var body: some View {
        Group {
            #if canImport(SwiftMath)
            MathUILabelView(latex: latex)
                .padding(.vertical, 4)
            #else
            // Web-based KaTeX fallback (auto-sizes; allows horizontal scroll)
            MathWebView(latex: latex, displayMode: true)
                .frame(minHeight: 28)
            #endif
        }
    }
}

#if canImport(Highlightr)
private struct HighlightedCodeView: UIViewRepresentable {
    let code: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.backgroundColor = UIColor.clear
        return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if let highlightr = Highlightr(),
           let theme = highlightr.setTheme(to: CodeTheme.current(for: colorScheme)) {
            highlightr.theme = theme
            let highlighted = highlightr.highlight(code, as: language)
            uiView.attributedText = highlighted
            uiView.textColor = UIColor.label
        } else {
            uiView.text = code
        }
    }
}
#elseif canImport(Highlighter)
import Highlighter
private struct HighlightedCodeView: UIViewRepresentable {
    let code: String
    let language: String?
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.backgroundColor = UIColor.clear
        return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Attempt a common theme; fall back gracefully
        if let highlighter = Highlighter() {
            let highlighted = highlighter.highlight(code, as: language ?? "") ?? NSAttributedString(string: code)
            uiView.attributedText = highlighted
            uiView.textColor = UIColor.label
        } else {
            uiView.text = code
        }
    }
}
#elseif canImport(HighlighterSwift)
import HighlighterSwift
private struct HighlightedCodeView: UIViewRepresentable {
    let code: String
    let language: String?
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.backgroundColor = UIColor.clear
        return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        // API shape assumption: HighlighterSwift().highlight(code:as:)
        // If unavailable, fall back to plain text gracefully.
        if let highlighter = HighlighterSwift() {
            let highlighted = highlighter.highlight(code: code, as: language ?? "") ?? NSAttributedString(string: code)
            uiView.attributedText = highlighted
            uiView.textColor = UIColor.label
        } else {
            uiView.text = code
        }
    }
}
#endif

#if canImport(SwiftMath)
private struct MathUILabelView: UIViewRepresentable {
    let latex: String
    func makeUIView(context: Context) -> MTMathUILabel {
        let v = MTMathUILabel()
        v.labelMode = .text
        v.textAlignment = .center
        v.latex = latex
        v.textColor = .label
        return v
    }
    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.latex = latex
        uiView.textColor = .label
    }
}
#endif

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
                    #if canImport(SwiftMath)
                    MathUILabelView(latex: ltx)
                    #else
                    MathWebView(latex: ltx, displayMode: false)
                        .frame(minHeight: 22)
                    #endif
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
