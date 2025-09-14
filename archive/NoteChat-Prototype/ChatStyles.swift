import SwiftUI
// MarkdownUI removed; styling is handled via ThemeTokens and Down renderer.

enum ChatStyle {
    static let bubbleCorner: CGFloat = 16
}

/// Highlight.js theme names used for syntax highlighting
enum CodeTheme {
    /// Theme optimized for light interface style
    static let light = "xcode"
    /// Theme optimized for dark interface style
    static let dark = "atom-one-dark"

    static func current(for colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? dark : light
    }
}

// MarkdownUI theme removed. Down-based renderer returns AttributedString.

