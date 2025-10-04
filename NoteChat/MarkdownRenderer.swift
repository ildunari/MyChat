// Rendering/MarkdownRenderer.swift
// Lightweight Markdown -> AttributedString pipeline using Down, with safe fallbacks.

import SwiftUI
import Foundation
import UIKit
#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(Down)
import Down
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
    // Cache raw parsed output to avoid re-parsing on every redraw
    let key = markdownCacheKey(markdown)
    if cachePolicy == .enabled, let cached = MarkdownCache.get(key) {
        return postProcess(cached, linkColor: linkColor, textColor: textColor)
    }
    // Optionally prefer Foundation's Markdown parser so resulting Text inherits SwiftUI environment
    // font design and dynamic type settings (for consistent app-wide appearance).
#if canImport(Down)
    let styler = MarkdownStylerFactory.styler(
        textColor: uiColor(from: textColor, fallback: .label),
        secondaryTextColor: UIColor.secondaryLabel,
        accentColor: uiColor(from: linkColor, fallback: .systemBlue)
    )
    if let attributed = try? Down(markdownString: markdown).toAttributedString(styler: styler) {
        let converted = AttributedString(attributed)
        if cachePolicy == .enabled { MarkdownCache.put(key, converted) }
        return postProcess(converted, linkColor: linkColor, textColor: textColor)
    }
#endif
    if preferSystemStyling {
        if let a = try? AttributedString(markdown: markdown) {
            if cachePolicy == .enabled { MarkdownCache.put(key, a) }
            return postProcess(a, linkColor: linkColor, textColor: textColor)
        }
        let a = AttributedString(markdown)
        if cachePolicy == .enabled { MarkdownCache.put(key, a) }
        return postProcess(a, linkColor: linkColor, textColor: textColor)
    }

    // Otherwise prefer Down (handles more complete Markdown than the Foundation parser alone)
    #if canImport(Down)
    do {
        let down = Down(markdownString: markdown)
        let ns = try down.toAttributedString()
        let raw = AttributedString(ns)
        if cachePolicy == .enabled { MarkdownCache.put(key, raw) }
        return postProcess(raw, linkColor: linkColor, textColor: textColor)
    } catch {
        if let a = try? AttributedString(markdown: markdown) {
            if cachePolicy == .enabled { MarkdownCache.put(key, a) }
            return postProcess(a, linkColor: linkColor, textColor: textColor)
        }
        let a = AttributedString(markdown)
        if cachePolicy == .enabled { MarkdownCache.put(key, a) }
        return postProcess(a, linkColor: linkColor, textColor: textColor)
    }
    #else
    // iOS 15+ AttributedString(markdown:) fallback
    if let a = try? AttributedString(markdown: markdown) {
        if cachePolicy == .enabled { MarkdownCache.put(key, a) }
        return postProcess(a, linkColor: linkColor, textColor: textColor)
    }
    let a = AttributedString(markdown)
    if cachePolicy == .enabled { MarkdownCache.put(key, a) }
    return postProcess(a, linkColor: linkColor, textColor: textColor)
    #endif
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

private func uiColor(from color: Color?, fallback: UIColor) -> UIColor {
    if let color {
        return UIColor(color)
    }
    return fallback
}
