// Markdown/MarkdownParser.swift
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Down)
import Down
#endif

// Central async parser with streaming/final policies and thread-safe cache
actor MarkdownParser {
    static let shared = MarkdownParser()

    private let cache = MarkdownCacheActor(maxEntries: 100)

    // Public API
    func parseStreaming(_ markdown: String) async -> AttributedString {
        let key = keyFor(text: markdown, mode: "stream")
        if let cached = await cache.get(key) { return cached }

        let parsed = parseInlineOnly(markdown) ?? (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        await cache.put(key, parsed)
        return parsed
    }

    func parseFinal(_ markdown: String, preferSystem: Bool) async -> AttributedString {
        let key = keyFor(text: markdown, mode: preferSystem ? "final_sys" : "final_down")
        if let cached = await cache.get(key) { return cached }

        let parsed: AttributedString
        if preferSystem {
            parsed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        } else {
            #if canImport(Down)
            if let a = try? Down(markdownString: markdown).toAttributedString() {
                parsed = AttributedString(a)
            } else {
                parsed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
            }
            #else
            parsed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
            #endif
        }

        await cache.put(key, parsed)
        return parsed
    }

    // MARK: - Private helpers

    // Try to use inline-only parsing during streaming when available
    private func parseInlineOnly(_ markdown: String) -> AttributedString? {
        // Availability guards: options api may not exist on older SDKs
        #if swift(>=5.7)
        if #available(iOS 16.0, macOS 13.0, *) {
            var options = AttributedString.MarkdownParsingOptions()
            // Best-effort: avoid heavy block-level parsing during streaming
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            // Be tolerant of malformed chunks while streaming
            options.failurePolicy = .returnPartiallyParsedIfPossible
            return try? AttributedString(markdown: markdown, options: options)
        }
        #endif
        return nil
    }
}

// Styling pass copied from previous renderer
// No-op post-process for now. Styling is handled by SwiftUI environment and code blocks.

// MARK: - Keying
extension MarkdownParser {
    nonisolated private static func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String(data.hashValue)
        #endif
    }

    private func keyFor(text: String, mode: String) -> String {
        Self.sha256(Data((mode + "|" + text).utf8))
    }
}
