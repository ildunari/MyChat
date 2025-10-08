import Foundation
import MarkdownUI

/// Accumulates streamed markdown fragments and exposes a stable prefix that is
/// safe to render via `MarkdownContent`, while holding any incomplete block in
/// `tailRaw` until its closing delimiter arrives.
struct StreamingMarkdownBuffer {
    struct TailState: Equatable {
        var codeFenceDelimiter: String?
        var isMathBlockOpen = false
        var inlineMathOpen = false
        var pendingTableAlignment = false
        /// Length (in UTF-16 code units) of the pending table header from the
        /// start of `tailRaw`. Used so we can flush the header back into the
        /// stable buffer if the alignment row never arrives.
        var pendingTableHeaderLength: Int = 0

        var describesIncompleteBlock: Bool {
            codeFenceDelimiter != nil || isMathBlockOpen || inlineMathOpen || pendingTableAlignment
        }
    }

    private(set) var stableRaw = ""
    private(set) var tailRaw = ""
    private(set) var tailState = TailState()

    var stableMarkdown: String { stableRaw }

    var stableContent: MarkdownContent {
        MarkdownContent(stableRaw)
    }

    var isEmpty: Bool {
        stableRaw.isEmpty && tailRaw.isEmpty
    }

    mutating func reset() {
        stableRaw = ""
        tailRaw = ""
        tailState = TailState()
    }

    mutating func replaceAll(with text: String) {
        reset()
        guard text.isEmpty == false else { return }
        tailRaw = normalizeNewlines(in: text)
        foldClosedSegments()
    }

    mutating func append(_ delta: String) {
        guard delta.isEmpty == false else { return }
        let normalized = normalizeNewlines(in: delta)

        // DEBUG: Show actual characters including newlines
        #if DEBUG
        let escaped = normalized.replacingOccurrences(of: "\n", with: "\\n")
        print("🔤 Buffer append: '\(escaped)'")
        #endif

        tailRaw.append(contentsOf: normalized)
        foldClosedSegments()
    }

    mutating func flushTail() {
        guard tailRaw.isEmpty == false else { return }
        stableRaw.append(tailRaw)
        tailRaw.removeAll(keepingCapacity: true)
        tailState = TailState()
    }

    // MARK: - Internal

    private mutating func foldClosedSegments() {
        let combined = MarkdownStreamSanitizer.sanitize(stableRaw + tailRaw)
        guard combined.isEmpty == false else {
            stableRaw = ""
            tailRaw = ""
            tailState = TailState()
            return
        }

        var index = combined.startIndex
        var latestCommittedIndex = combined.startIndex
        var codeFenceDelimiter: String?
        var codeFenceStart: String.Index?
        var mathBlockOpen = false
        var mathBlockStart: String.Index?
        var pendingTableAlignment = false
        var tableHeaderStart: String.Index?
        var tableHeaderEnd: String.Index?

        while index < combined.endIndex {
            let lineRange = combined.lineRange(for: index..<index)
            let line = String(combined[lineRange])
            let trimmed = trimLine(line)
            var nextIndex = lineRange.upperBound

            if let delimiter = codeFenceDelimiter {
                if isFenceLine(trimmed, matching: delimiter) {
                    codeFenceDelimiter = nil
                    codeFenceStart = nil
                    latestCommittedIndex = lineRange.upperBound
                }
            } else if mathBlockOpen {
                if isMathFence(trimmed) {
                    mathBlockOpen = false
                    mathBlockStart = nil
                    latestCommittedIndex = lineRange.upperBound
                }
            } else if pendingTableAlignment {
                if let headerStart = tableHeaderStart, lineRange.lowerBound == headerStart {
                    // Still on header line; wait for following alignment row.
                } else if isTableAlignmentRow(trimmed) {
                    pendingTableAlignment = false
                    tableHeaderStart = nil
                    tableHeaderEnd = nil
                    latestCommittedIndex = lineRange.upperBound
                } else if trimmed.isEmpty {
                    pendingTableAlignment = false
                    if let headerEnd = tableHeaderEnd {
                        latestCommittedIndex = headerEnd
                    }
                    tableHeaderStart = nil
                    tableHeaderEnd = nil
                } else {
                    pendingTableAlignment = false
                    if let headerEnd = tableHeaderEnd {
                        latestCommittedIndex = headerEnd
                    }
                    tableHeaderStart = nil
                    tableHeaderEnd = nil
                    // Reprocess this line as plain markdown.
                    nextIndex = lineRange.lowerBound
                }
            } else {
                if let fence = fenceDelimiter(in: trimmed) {
                    codeFenceDelimiter = fence
                    codeFenceStart = lineRange.lowerBound
                    latestCommittedIndex = min(latestCommittedIndex, lineRange.lowerBound)
                } else if opensMathBlock(trimmed) {
                    mathBlockOpen = true
                    mathBlockStart = lineRange.lowerBound
                    latestCommittedIndex = min(latestCommittedIndex, lineRange.lowerBound)
                } else if isTableHeader(trimmed) {
                    pendingTableAlignment = true
                    tableHeaderStart = lineRange.lowerBound
                    tableHeaderEnd = lineRange.upperBound
                    latestCommittedIndex = min(latestCommittedIndex, lineRange.lowerBound)
                } else {
                    latestCommittedIndex = lineRange.upperBound
                }
            }

            index = nextIndex
        }

        var tailStartIndex = latestCommittedIndex
        if let start = codeFenceStart {
            tailStartIndex = min(tailStartIndex, start)
        }
        if let start = mathBlockStart {
            tailStartIndex = min(tailStartIndex, start)
        }
        if pendingTableAlignment, let start = tableHeaderStart {
            tailStartIndex = min(tailStartIndex, start)
        }

        tailStartIndex = max(tailStartIndex, combined.startIndex)

        // Check for unclosed inline math in the stable portion
        let stableSlice = combined[..<tailStartIndex]
        var inlineMathOpen = false
        if let unclosedIndex = findUnclosedInlineMath(in: String(stableSlice)) {
            // Found unclosed inline math - move tail start back to include it
            tailStartIndex = unclosedIndex
            inlineMathOpen = true
        }

        let finalStableSlice = combined[..<tailStartIndex]
        let tailSlice = combined[tailStartIndex...]

        stableRaw = String(finalStableSlice)
        tailRaw = String(tailSlice)

        var newState = TailState()
        newState.codeFenceDelimiter = codeFenceDelimiter
        newState.isMathBlockOpen = mathBlockOpen
        newState.inlineMathOpen = inlineMathOpen
        newState.pendingTableAlignment = pendingTableAlignment
        if pendingTableAlignment {
            let headerRange = tailRaw.lineRange(for: tailRaw.startIndex..<tailRaw.startIndex)
            newState.pendingTableHeaderLength = tailRaw[headerRange].utf16.count
        }
        tailState = newState
    }

    private func normalizeNewlines(in text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func fenceDelimiter(in line: String) -> String? {
        guard line.hasPrefix("```") || line.hasPrefix("~~~") || line.hasPrefix("'''") else { return nil }
        let prefix = line.prefix { $0 == "`" || $0 == "~" || $0 == "'" }
        return prefix.count >= 3 ? String(prefix.replacingOccurrences(of: "'", with: "`")) : nil
    }

    private func isFenceLine(_ line: String, matching delimiter: String) -> Bool {
        guard let marker = delimiter.first else { return false }
        let prefix = line.prefix { $0 == marker }
        guard prefix.count >= delimiter.count else { return false }
        let remainder = line.dropFirst(prefix.count)
        return remainder.allSatisfy { $0.isWhitespace }
    }

    private func opensMathBlock(_ line: String) -> Bool {
        guard line.contains("$$") else { return false }
        let occurrences = line.components(separatedBy: "$$").count - 1
        if occurrences >= 2 { return false }
        return line == "$$"
    }

    private func isMathFence(_ line: String) -> Bool {
        line == "$$"
    }

    private func isTableHeader(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        let segments = trimmed.split(separator: "|", omittingEmptySubsequences: false)
        return segments.count > 2
    }

    private func isTableAlignmentRow(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        let allowed = CharacterSet(charactersIn: "|:- ")
        return line.unicodeScalars.allSatisfy { allowed.contains($0) } && line.contains("-")
    }

    private func trimLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Finds the last unclosed inline math delimiter ($) in the text.
    /// Returns the index of the opening $ if found, nil if all $ are closed.
    private func findUnclosedInlineMath(in text: String) -> String.Index? {
        var index = text.startIndex
        var lastOpenDollar: String.Index?
        var isEscaped = false

        while index < text.endIndex {
            let char = text[index]

            if char == "\\" && !isEscaped {
                isEscaped = true
            } else if char == "$" && !isEscaped {
                if let open = lastOpenDollar {
                    let segment = text[text.index(after: open)..<index]
                    if shouldIgnoreMathSegment(segment) {
                        lastOpenDollar = nil
                    } else {
                        lastOpenDollar = nil
                    }
                } else {
                    lastOpenDollar = index
                }
                isEscaped = false
            } else {
                isEscaped = false
            }

            index = text.index(after: index)
        }

        if let open = lastOpenDollar {
            let tail = text[text.index(after: open)..<text.endIndex]
            if shouldIgnoreMathSegment(tail) {
                return nil
            }
        }

        return lastOpenDollar
    }

    private func shouldIgnoreMathSegment(_ substring: Substring) -> Bool {
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.letters.contains(scalar) { return false }
            if "=\\+-*/^_<>[]()".unicodeScalars.contains(scalar) { return false }
        }

        return true
    }
}
