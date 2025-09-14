import Foundation

/// A tiny, future-proof editing engine for Notes that supports
/// search/replace, regex, position-based edits (UTF-16), and a minimal
/// unified-diff applier. Designed for AI-driven editing.
struct NoteEditCommand: Sendable {
    enum Kind: Sendable {
        case setTitle(String)
        case replace(range: NSRange, with: String)        // UTF-16 range
        case insert(offset: Int, text: String)            // UTF-16 offset
        case delete(range: NSRange)                       // UTF-16 range
        case regex(pattern: String, replacement: String, options: NSRegularExpression.Options = [.caseInsensitive])
        case unifiedDiff(String)                          // Minimal unified diff text
    }
    let kind: Kind
}

extension Note {
    /// Apply a sequence of edit commands atomically. If a command fails, later commands still run.
    func apply(commands: [NoteEditCommand]) {
        for cmd in commands { apply(command: cmd) }
        updatedAt = Date()
    }

    func apply(command: NoteEditCommand) {
        switch command.kind {
        case .setTitle(let t):
            title = t
        case .replace(let range, let text):
            replaceUTF16Range(range, with: text)
        case .insert(let offset, let text):
            let r = NSRange(location: offset, length: 0)
            replaceUTF16Range(r, with: text)
        case .delete(let range):
            replaceUTF16Range(range, with: "")
        case .regex(let pattern, let repl, let opts):
            regexReplace(pattern: pattern, replacement: repl, options: opts)
        case .unifiedDiff(let diff):
            _ = applyUnifiedDiff(diff)
        }
    }

    /// Very small unified diff applier that supports a subset of the format.
    /// Intended as a foundation – extend as needed.
    /// Returns true if at least one hunk was applied.
    @discardableResult
    func applyUnifiedDiff(_ diff: String) -> Bool {
        // Recognize hunks starting with "@@ -l,s +l,s @@"
        // We only apply additions/removals within context – no file headers.
        // Strategy: convert current content to lines; apply hunks; then join.
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result = lines
        var applied = false
        var i = 0
        let all = diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        func parseRange(_ token: String) -> (start: Int, count: Int)? {
            // token like "-12,3" or "+5,10" without the sign
            let comps = token.split(separator: ",").map(String.init)
            guard let start = Int(comps.first ?? ""), let count = Int(comps.dropFirst().first ?? "1") else { return nil }
            return (start, count)
        }

        while i < all.count {
            let line = all[i]
            if line.hasPrefix("@@ ") && line.contains(" @@") {
                // Example: @@ -l1,s1 +l2,s2 @@ optional heading
                // Extract ranges
                let parts = line.replacingOccurrences(of: "@@ ", with: "").replacingOccurrences(of: " @@", with: "").split(separator: " ")
                guard parts.count >= 2 else { i += 1; continue }
                let minus = parts[0] // like -12,3
                let plus = parts[1]  // like +12,4
                guard minus.first == "-", plus.first == "+",
                      let r1 = parseRange(String(minus.dropFirst())),
                      let _ = parseRange(String(plus.dropFirst())) else { i += 1; continue }
                // Convert to 0-based indices
                let baseStart = max(0, r1.start - 1)
                // Collect hunk body lines until next hunk or EOF
                var body: [String] = []
                i += 1
                while i < all.count, all[i].hasPrefix("@@ ") == false {
                    body.append(all[i]); i += 1
                }
                // Build new slice: context ' ' lines, removed '-' lines, added '+' lines
                var newSlice: [String] = []
                var readIndex = baseStart
                var ok = true
                for b in body {
                    if b.hasPrefix(" ") { // context must match
                        let ctx = String(b.dropFirst())
                        guard readIndex < result.count, result[readIndex] == ctx else { ok = false; break }
                        newSlice.append(ctx); readIndex += 1
                    } else if b.hasPrefix("-") {
                        let rem = String(b.dropFirst())
                        guard readIndex < result.count, result[readIndex] == rem else { ok = false; break }
                        // skip the removed line by advancing readIndex; don't append
                        readIndex += 1
                    } else if b.hasPrefix("+") {
                        let add = String(b.dropFirst())
                        newSlice.append(add)
                    } else if b.isEmpty { // treat as context empty line
                        guard readIndex < result.count, result[readIndex].isEmpty else { ok = false; break }
                        newSlice.append(""); readIndex += 1
                    } else {
                        ok = false; break
                    }
                }
                if ok {
                    // Apply: replace the slice starting at baseStart with newSlice
                    let end = readIndex
                    if baseStart <= result.count {
                        result.replaceSubrange(baseStart..<min(end, result.count), with: newSlice)
                        applied = true
                    }
                }
            } else {
                i += 1
            }
        }
        if applied { content = result.joined(separator: "\n") }
        return applied
    }
}

