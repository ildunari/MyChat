import Foundation
import SwiftUI
import MarkdownUI

enum MarkdownThemeFactory {
    static func chatTheme(tokens: ThemeTokens, colorScheme: ColorScheme) -> Theme {
        Theme.basic
            .text {
                ForegroundColor(tokens.text)
            }
            .link {
                ForegroundColor(tokens.link)
            }
            .code {
                FontFamilyVariant(.monospaced)
                ForegroundColor(tokens.text)
            }
            .blockquote { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(tokens.textSecondary)
                    }
                    .modifier(BlockquoteContainer(tokens: tokens, colorScheme: colorScheme))
                    .markdownMargin(top: .zero, bottom: .em(1))
            }
            .codeBlock { configuration in
                AsyncHighlightedCodeBlock(configuration: configuration, tokens: tokens)
                    .modifier(CodeBlockContainer(tokens: tokens, colorScheme: colorScheme))
                    .markdownMargin(top: .zero, bottom: .em(1))
            }
            .table { configuration in
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                }
                .modifier(TableContainer(tokens: tokens, colorScheme: colorScheme))
                .markdownMargin(top: .zero, bottom: .em(1))
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                    }
                    .relativePadding(.horizontal, length: .em(0.7))
                    .relativePadding(.vertical, length: .em(0.45))
            }
    }
}

struct AsyncHighlightedCodeBlock: View {
    let configuration: CodeBlockConfiguration
    let tokens: ThemeTokens
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted: AttributedString?
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: true) {
                Group {
                    if let highlighted {
                        Text(highlighted)
                    } else {
                        Text(configuration.content)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .modifier(CodeBlockContainer(tokens: tokens, colorScheme: colorScheme))

            Button(action: copyToPasteboard) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(10)
            .buttonStyle(.plain)
            .opacity(configuration.content.isEmpty ? 0 : 1)
        }
        .task(id: taskIdentifier) {
            highlighted = await CodeHighlightBridge.highlight(configuration.content,
                                                              language: configuration.language,
                                                              colorScheme: colorScheme)
            copied = false
        }
    }

    private var taskIdentifier: String {
        "\(configuration.language ?? "")::\(configuration.content)::\(colorScheme == .dark ? "dark" : "light")"
    }

    private func copyToPasteboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = configuration.content
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            copied = false
        }
        #endif
    }
}

enum MarkdownStreamSanitizer {
    static func sanitize(_ input: String) -> String {
        guard input.isEmpty == false else { return input }
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var sanitized: [String] = []
        sanitized.reserveCapacity(lines.count + 4)

        for rawLine in lines {
            let indentSubstring = rawLine.prefix { $0 == " " || $0 == "\t" }
            let indent = String(indentSubstring)
            let body = String(rawLine.dropFirst(indentSubstring.count))

            let pieces = sanitizeLineBody(body)
            for piece in pieces {
                sanitized.append(indent + piece)
            }
        }

        return sanitized.joined(separator: "\n")
    }

    private static func sanitizeLineBody(_ line: String) -> [String] {
        var working = convertApostropheFence(in: line)
        working = ensureHeadingSpacing(working)
        working = normalizeTaskCheckbox(working)
        working = stripTableBulletPrefix(working)

        var segments: [String] = [working]
        segments = segments.flatMap { insertBreaksBeforeKeywords($0) }
        segments = segments.flatMap { splitBlockMathIfNeeded($0) }
        segments = segments.flatMap { splitBeforeTablePipe($0) }

        var results: [String] = []
        for segment in segments {
            if let split = splitRunOnList(in: segment) {
                results.append(contentsOf: sanitizeLineBody(split.current))
                results.append(contentsOf: sanitizeLineBody(split.next))
                continue
            }
            if let splitFence = splitInlineFence(in: segment) {
                results.append(contentsOf: sanitizeLineBody(splitFence.current))
                results.append(contentsOf: sanitizeLineBody(splitFence.next))
                continue
            }
            if let compressed = splitCompressedList(in: segment) {
                results.append(contentsOf: sanitizeLineBody(compressed.current))
                results.append(contentsOf: sanitizeLineBody(compressed.next))
                continue
            }
            results.append(segment)
        }

        return results
    }

    private static func convertApostropheFence(in line: String) -> String {
        guard line.hasPrefix("'''") else { return line }
        let prefix = line.prefix { $0 == "'" }
        guard prefix.count >= 3 else { return line }
        let delimiter = String(repeating: "`", count: prefix.count)
        let remainder = line.dropFirst(prefix.count)
        return delimiter + remainder
    }

    private static func ensureHeadingSpacing(_ line: String) -> String {
        guard line.first == "#" else { return line }
        let hashes = line.prefix { $0 == "#" }
        let count = hashes.count
        guard count > 0, count <= 6 else { return line }
        let remainder = line.dropFirst(count)
        guard remainder.isEmpty == false else { return line }
        guard remainder.first?.isWhitespace == false else { return line }
        return String(hashes) + " " + remainder
    }

    private static func normalizeTaskCheckbox(_ line: String) -> String {
        var line = line
        line = line.replacingOccurrences(of: "-[]", with: "- [ ]")
        line = line.replacingOccurrences(of: "-[ ]", with: "- [ ]")
        line = line.replacingOccurrences(of: "- [x]", with: "- [x]")
        line = line.replacingOccurrences(of: "- [X]", with: "- [x]")
        return line
    }

    private static func stripTableBulletPrefix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- |"), let range = line.range(of: "- |") {
            var output = line
            output.removeSubrange(range)
            return output.trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private static func insertBreaksBeforeKeywords(_ line: String) -> [String] {
        let keywords = ["Inline code", "Unordered list", "Ordered list", "Nested lists", "Task Lists", "Blockquotes", "Tables", "Images", "Horizontal Rule", "Escaping", "Math", "Footnotes", "Details", "Task:"]
        var segments: [String] = [line]
        for keyword in keywords {
            var updated: [String] = []
            for segment in segments {
                guard let range = segment.range(of: keyword), range.lowerBound != segment.startIndex else {
                    updated.append(segment)
                    continue
                }
                let before = segment[..<range.lowerBound]
                if before.trimmingCharacters(in: .whitespaces).isEmpty == false {
                    updated.append(String(before))
                }
                updated.append(String(segment[range.lowerBound...]))
            }
            segments = updated
        }
        return segments
    }

    private static func splitBlockMathIfNeeded(_ line: String) -> [String] {
        let occurrences = line.components(separatedBy: "$").count - 1
        guard occurrences >= 2 else { return [line] }
        if line.contains("$$") {
            var segments: [String] = []
            var iterator = line[...]
            while let range = iterator.range(of: "$$") {
                let prefix = iterator[..<range.lowerBound]
                if prefix.isEmpty == false {
                    segments.append(prefix.trimmingCharacters(in: .whitespaces))
                }
                segments.append("$$")
                iterator = iterator[range.upperBound...]
            }
            if iterator.isEmpty == false {
                segments.append(String(iterator).trimmingCharacters(in: .whitespaces))
            }
            return segments.filter { $0.isEmpty == false }
        }
        return [line]
    }

    private static func splitBeforeTablePipe(_ line: String) -> [String] {
        guard line.contains("|") else { return [line] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") == false else { return [line] }
        guard let pipeIndex = line.firstIndex(of: "|") else { return [line] }
        let before = line[..<pipeIndex]
        let after = line[pipeIndex...]
        if before.trimmingCharacters(in: .whitespaces).isEmpty {
            return [String(after)]
        }
        return [String(before), String(after)]
    }

    private static func splitRunOnList(in line: String) -> (current: String, next: String)? {
        guard line.isEmpty == false else { return nil }
        let markers = ["- ", "* ", "+ "]
        for marker in markers {
            guard let range = line.range(of: marker) else { continue }
            guard range.lowerBound != line.startIndex else { continue }
            let before = line[..<range.lowerBound]
            guard before.last?.isWhitespace == false else { continue }
            let first = before.trimmingCharacters(in: .whitespaces)
            let second = line[range.lowerBound...].trimmingCharacters(in: .whitespaces)
            guard first.isEmpty == false, second.isEmpty == false else { continue }
            return (String(first), String(second))
        }
        return nil
    }

    private static func splitCompressedList(in line: String) -> (current: String, next: String)? {
        guard line.isEmpty == false else { return nil }
        guard let index = line.firstIndex(of: "-") else { return nil }
        guard index != line.startIndex else { return nil }
        let before = line[..<index]
        guard before.last?.isWhitespace == false else { return nil }
        let remainder = line[index...]
        let first = before.trimmingCharacters(in: .whitespaces)
        let second = remainder.hasPrefix("-") ? String(remainder) : "- " + remainder.trimmingCharacters(in: .whitespaces)
        guard first.isEmpty == false, second.isEmpty == false else { return nil }
        return (String(first), second)
    }

    private static func splitInlineFence(in line: String) -> (current: String, next: String)? {
        guard line.isEmpty == false else { return nil }
        let fences = ["```", "~~~"]
        for fence in fences {
            guard let range = line.range(of: fence) else { continue }
            guard range.lowerBound != line.startIndex else { continue }
            let before = line[..<range.lowerBound]
            guard before.last?.isWhitespace == false else { continue }
            let first = String(before)
            let second = String(line[range.lowerBound...])
            guard first.isEmpty == false, second.isEmpty == false else { continue }
            return (first, second)
        }
        return nil
    }
}

// MARK: - Shared view modifiers used across rendered markdown

struct BlockquoteContainer: ViewModifier {
    let tokens: ThemeTokens
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.leading, 14)
            .background(
                RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                    .fill(tokens.surface.opacity(colorScheme == .dark ? 0.65 : 0.92))
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tokens.borderSoft.opacity(0.9))
                    .frame(width: 3)
            }
    }
}

struct CodeBlockContainer: ViewModifier {
    let tokens: ThemeTokens
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                    .fill(tokens.codeBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                    .stroke(tokens.borderSoft.opacity(0.8), lineWidth: 1)
            )
    }
}

struct TableContainer: ViewModifier {
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

