import UIKit
import SwiftUI

/// Minimal markdown styling helper that relies on Swift's `AttributedString(markdown:)`
/// and reapplies base attributes used by the editor.
enum MarkdownStyler {
    static func editorAttributedString(for markdown: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attributed: AttributedString
        if let parsed = try? AttributedString(markdown: markdown) {
            attributed = parsed
        } else {
            attributed = AttributedString(markdown)
        }

        // Ensure inline code uses a monospaced face to mirror the previous Down styling.
        for run in attributed.runs {
            if let intents = run.attributes.inlinePresentationIntent, intents.contains(.code) {
                attributed[run.range].font = .system(.body, design: .monospaced)
            }
        }

        let ns = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        if !baseAttributes.isEmpty {
            ns.addAttributes(baseAttributes, range: NSRange(location: 0, length: ns.length))
        }
        return ns
    }
}
