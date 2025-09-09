// Rendering/MarkdownRenderer.swift
// Lightweight Markdown -> AttributedString pipeline using Down, with safe fallbacks.

import SwiftUI
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Down)
import Down
#endif

/// Renders markdown into an AttributedString suitable for SwiftUI Text.
/// - Parameter markdown: source markdown text
/// - Returns: AttributedString with basic styling applied. Falls back to AttributedString(markdown:) if Down is unavailable.
func renderMarkdownAttributed(_ markdown: String, linkColor: Color? = nil) -> AttributedString {
    // Cache raw parsed output to avoid re-parsing on every redraw
    let key = markdownCacheKey(markdown)
    if let cached = MarkdownCache.get(key) {
        return postProcess(cached, linkColor: linkColor)
    }
    // Prefer Down when available (handles more complete Markdown than the Foundation parser alone)
    #if canImport(Down)
    do {
        let down = Down(markdownString: markdown)
        let ns = try down.toAttributedString()
        let raw = AttributedString(ns)
        MarkdownCache.put(key, raw)
        return postProcess(raw, linkColor: linkColor)
    } catch {
        // Fall back to Foundation's Markdown parser
        if let a = try? AttributedString(markdown: markdown) {
            MarkdownCache.put(key, a)
            return postProcess(a, linkColor: linkColor)
        }
        let a = AttributedString(markdown)
        MarkdownCache.put(key, a)
        return postProcess(a, linkColor: linkColor)
    }
    #else
    // iOS 15+ AttributedString(markdown:) fallback
    if let a = try? AttributedString(markdown: markdown) {
        MarkdownCache.put(key, a)
        return postProcess(a, linkColor: linkColor)
    }
    let a = AttributedString(markdown)
    MarkdownCache.put(key, a)
    return postProcess(a, linkColor: linkColor)
    #endif
}

// MARK: - Lightweight styling pass

private func postProcess(_ input: AttributedString, linkColor: Color?) -> AttributedString {
    var a = input
    // Tint links, preserving underline
    if let color = linkColor {
        for run in a.runs {
            if run.attributes.link != nil {
                a[run.range].foregroundColor = color
            }
        }
    }
    // Monospaced inline code (when detectable via inlinePresentationIntent)
    for run in a.runs {
        if let intents = run.attributes.inlinePresentationIntent, intents.contains(.code) {
            a[run.range].font = .system(.body, design: .monospaced)
        }
    }
    return a
}

// MARK: - Simple in-memory LRU cache (50 entries)

private enum MarkdownCache {
    private static var dict: [String: AttributedString] = [:]
    private static var order: [String] = []
    private static let maxEntries = 50

    static func get(_ key: String) -> AttributedString? { dict[key] }

    static func put(_ key: String, _ value: AttributedString) {
        if dict[key] == nil { order.append(key) }
        dict[key] = value
        if order.count > maxEntries, let drop = order.first {
            dict.removeValue(forKey: drop)
            order.removeFirst()
        }
    }
}

private func markdownCacheKey(_ s: String) -> String {
    #if canImport(CryptoKit)
    let digest = SHA256.hash(data: Data(s.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    return String(s.hashValue)
    #endif
}
