// Rendering/MarkdownRenderer.swift
// Lightweight Markdown -> AttributedString pipeline using Down, with safe fallbacks.

import SwiftUI

#if canImport(Down)
import Down
#endif

/// Renders markdown into an AttributedString suitable for SwiftUI Text.
/// - Parameter markdown: source markdown text
/// - Returns: AttributedString with basic styling applied. Falls back to AttributedString(markdown:) if Down is unavailable.
func renderMarkdownAttributed(_ markdown: String) -> AttributedString {
    // Prefer Down when available (handles more complete Markdown than the Foundation parser alone)
    #if canImport(Down)
    do {
        let down = Down(markdownString: markdown)
        let ns = try down.toAttributedString()
        return AttributedString(ns)
    } catch {
        // Fall back to Foundation's Markdown parser
        if let a = try? AttributedString(markdown: markdown) {
            return a
        }
        return AttributedString(markdown)
    }
    #else
    // iOS 15+ AttributedString(markdown:) fallback
    if let a = try? AttributedString(markdown: markdown) {
        return a
    }
    return AttributedString(markdown)
    #endif
}
