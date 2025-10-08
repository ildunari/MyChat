// Rendering/MarkdownRenderer.swift
// Lightweight Markdown -> AttributedString pipeline backed by Swift's Markdown parser.

import SwiftUI
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

enum MarkdownCachePolicy { case enabled, bypass }

/// Renders markdown into an AttributedString suitable for SwiftUI Text.
/// - Parameter markdown: source markdown text
/// - Returns: AttributedString with basic styling applied. Falls back to AttributedString(markdown:) if Down is unavailable.
func renderMarkdownAttributed(_ markdown: String,
                              linkColor: Color? = nil,
                              textColor: Color? = nil,
                              preferSystemStyling: Bool = false,
                              cachePolicy: MarkdownCachePolicy = .enabled) -> AttributedString {
    let key = markdownCacheKey(markdown)
    if cachePolicy == .enabled, let cached = MarkdownCache.get(key) {
        return preferSystemStyling ? cached : postProcess(cached, linkColor: linkColor, textColor: textColor)
    }

    let parsed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    if cachePolicy == .enabled { MarkdownCache.put(key, parsed) }
    return preferSystemStyling ? parsed : postProcess(parsed, linkColor: linkColor, textColor: textColor)
}

// MARK: - Lightweight styling pass

private func postProcess(_ input: AttributedString,
                        linkColor: Color?,
                        textColor: Color?) -> AttributedString {
    var a = input
    // Tint links, preserving underline
    if let color = linkColor {
        for run in a.runs {
            if run.attributes.link != nil {
                a[run.range].foregroundColor = color
            }
        }
    }
    if let base = textColor {
        for run in a.runs where run.attributes.link == nil {
            a[run.range].foregroundColor = base
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
