// Views/AIResponseView.swift
import SwiftUI

// MarkdownUI removed in favor of Down renderer

#if canImport(Highlightr)
import Highlightr
#endif

import SwiftMath // SwiftMath provides MTMathUILabel for native LaTeX rendering

struct AIResponseView: View {
    let content: String
    var isStreaming: Bool = false // Flag to optimize for streaming scenarios
    @Environment(\.tokens) private var T

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseBlocks(from: content)) { block in
                switch block.kind {
                case .markdown(let text):
                    MarkdownSegment(text: text, isStreaming: isStreaming)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let lang, let code):
                    CodeBlockSegment(language: lang, code: code)
                case .math(let latex):
                    MathBlockSegment(latex: latex)
                }
            }
        }
        .padding(.vertical, 2)
        .tint(T.link)
        .id(isStreaming ? "streaming" : content.prefix(50)) // Optimize SwiftUI diffing
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
    var isStreaming: Bool = false
    @Environment(\.tokens) private var T
    @State private var debouncedText: String = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isStreaming {
                markdownTextView(for: effectiveText)
            } else {
                let pieces = markdownPieces(from: effectiveText)
                if pieces.count == 1, case .text(let chunk) = pieces.first {
                    markdownTextView(for: chunk)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                            switch piece {
                            case .text(let chunk):
                                markdownTextView(for: chunk)
                            case .table(let table):
                                MarkdownTableView(table: table)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            if isStreaming {
                // Debounce markdown rendering during streaming for better performance
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        debouncedText = newValue
                    }
                }
            } else {
                debouncedText = newValue
            }
        }
        .onAppear {
            debouncedText = text
        }
    }
    
    private var effectiveText: String {
        isStreaming ? debouncedText : text
    }

    @ViewBuilder
    private func markdownTextView(for text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else if containsInlineMath(text) {
            InlineMathParagraph(text: text)
                .foregroundStyle(T.text)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let attributed = renderMarkdownAttributed(text,
                                                      linkColor: T.link,
                                                      textColor: T.text,
                                                      preferSystemStyling: true,
                                                      cachePolicy: isStreaming ? .bypass : .enabled)
            Text(attributed)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CodeBlockSegment: View {
    let language: String?
    let code: String
    @Environment(\.tokens) private var T
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Group {
                #if canImport(Highlightr) || canImport(Highlighter) || canImport(HighlighterSwift)
                HighlightedCodeView(code: code, language: language)
                    .padding(12)
                #else
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                #endif
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(T.codeBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(T.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
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

#if canImport(Highlightr)
private struct HighlightedCodeView: UIViewRepresentable {
    let code: String
    let language: String?
    @Environment(\.colorScheme) private var colorScheme
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
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
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
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
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
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

private func containsInlineMath(_ text: String) -> Bool {
    guard text.contains("$") else { return false }
    // Require at least one non-whitespace character between delimiters
    // Avoid matching lone $ or $$ (which are block delimiters)
    return text.range(of: #"\$[^\s$][^$\n]*[^\s$]\$"#, options: .regularExpression) != nil
}

private func parseInlineMath(_ s: String) -> [InlinePiece] {
    var out: [InlinePiece] = []
    var buffer = ""
    var i = s.startIndex
    var inMath = false
    while i < s.endIndex {
        let ch = s[i]
        if ch == "$" {
            // Check for $$ (block delimiter - treat as literal)
            let nextIndex = s.index(after: i)
            if nextIndex < s.endIndex, s[nextIndex] == "$" {
                buffer.append("$$")
                i = s.index(after: nextIndex)
                continue
            }
            
            if inMath {
                // Closing delimiter - validate content has non-whitespace
                let trimmed = buffer.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    out.append(.math(buffer))
                } else {
                    // Invalid math (empty or whitespace only) - treat as literal
                    if !buffer.isEmpty { out.append(.text("$\(buffer)$")) }
                    else { out.append(.text("$$")) }
                }
                buffer.removeAll()
                inMath = false
            } else {
                // Opening delimiter
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
        // Unclosed math delimiter - treat as literal text
        out.append(inMath ? .text("$\(buffer)") : .text(buffer))
    }
    return out
}

private enum MarkdownPiece { case text(String), table(MarkdownTable) }

private func markdownPieces(from text: String) -> [MarkdownPiece] {
    var pieces: [MarkdownPiece] = []
    let segments = text.components(separatedBy: "\n\n")
    for segment in segments {
        if isTableBlock(segment), let table = parseMarkdownTable(from: segment) {
            pieces.append(.table(table))
        } else {
            pieces.append(.text(segment))
        }
    }
    return pieces
}

private func isTableBlock(_ text: String) -> Bool {
    let lines = text.split(separator: "\n")
    guard lines.count >= 2 else { return false }
    let body = lines.map { $0.trimmingCharacters(in: .whitespaces) }
    guard body.contains(where: { $0.contains("|") }) else { return false }
    return body.dropFirst().contains { $0.contains("---") || $0.contains(":-") }
}

private struct MarkdownTable {
    enum Alignment {
        case leading, center, trailing

        var horizontalAlignment: HorizontalAlignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }

        var textAlignment: TextAlignment {
            switch self {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
            }
        }

        var frameAlignment: SwiftUI.Alignment {
            SwiftUI.Alignment(horizontal: horizontalAlignment, vertical: .center)
        }
    }

    var headers: [String]
    var rows: [[String]]
    var alignments: [Alignment]
}

private func parseMarkdownTable(from block: String) -> MarkdownTable? {
    let rawLines = block.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.isEmpty == false }
    guard rawLines.count >= 2 else { return nil }

    guard let headerIndex = rawLines.firstIndex(where: { $0.contains("|") }) else { return nil }
    let candidates = Array(rawLines.suffix(from: headerIndex))
    guard candidates.count >= 2 else { return nil }
    let headerLine = candidates[0]
    let separatorLine = candidates[1]
    let bodyLines = Array(candidates.dropFirst(2))

    let headers = splitTableRow(headerLine)
    var alignments = parseAlignmentRow(separatorLine, expectedCount: headers.count)
    if alignments.count < headers.count {
        alignments += Array(repeating: .leading, count: headers.count - alignments.count)
    }

    var rows: [[String]] = []
    for line in bodyLines {
        var cells = splitTableRow(line)
        if cells.count < headers.count {
            cells += Array(repeating: "", count: headers.count - cells.count)
        }
        rows.append(cells)
    }

    return MarkdownTable(headers: headers, rows: rows, alignments: alignments)
}

private func splitTableRow(_ line: String) -> [String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let withoutPipes = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
    return withoutPipes
        .components(separatedBy: "|")
        .map { $0.trimmingCharacters(in: .whitespaces) }
}

private func parseAlignmentRow(_ line: String, expectedCount: Int) -> [MarkdownTable.Alignment] {
    let tokens = splitTableRow(line)
    return tokens.prefix(expectedCount).map { token in
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        let startsWithColon = trimmed.hasPrefix(":")
        let endsWithColon = trimmed.hasSuffix(":")

        switch (startsWithColon, endsWithColon) {
        case (true, true): return .center
        case (false, true): return .trailing
        case (true, false): return .leading
        default: return .leading
        }
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownTable
    @Environment(\.tokens) private var T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        ForEach(Array(table.headers.enumerated()), id: \.offset) { index, header in
                            Text(header.isEmpty ? " " : header)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(table.alignments[safe: index]?.textAlignment ?? .leading)
                                .frame(maxWidth: .infinity,
                                       alignment: table.alignments[safe: index]?.frameAlignment ?? .leading)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(T.surfaceElevated.opacity(0.85))

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                        Divider()
                            .gridCellUnsizedAxes([.horizontal, .vertical])

                        GridRow {
                            ForEach(0..<table.headers.count, id: \.self) { column in
                                let text = column < row.count ? row[column] : ""
                                Text(text.isEmpty ? " " : text)
                                    .font(.callout)
                                    .multilineTextAlignment(table.alignments[safe: column]?.textAlignment ?? .leading)
                                    .frame(maxWidth: .infinity,
                                           alignment: table.alignments[safe: column]?.frameAlignment ?? .leading)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(rowIndex % 2 == 0 ? T.surface.opacity(0.28) : T.surface.opacity(0.14))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(T.surfaceElevated.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(T.borderSoft.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: T.shadow.opacity(0.08), radius: 10, y: 6)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
