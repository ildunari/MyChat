import Foundation
import SwiftUI
import Down

enum MarkdownStyler {
    static func editorAttributedString(for text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)

        // Headings: #, ##, ... up to ######
        if let headingRegex = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$", options: [.anchorsMatchLines]) {
            let matches = headingRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let hashesRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                let level = max(1, min(6, hashesRange.length))
                let fontSize: CGFloat
                switch level {
                case 1: fontSize = 30
                case 2: fontSize = 26
                case 3: fontSize = 24
                case 4: fontSize = 22
                case 5: fontSize = 20
                default: fontSize = 18
                }
                let headingFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                attributed.addAttributes([
                    .font: headingFont,
                    .foregroundColor: UIColor.label
                ], range: contentRange)

                // Dim the markdown markers (#)
                attributed.addAttributes([
                    .foregroundColor: UIColor.secondaryLabel
                ], range: hashesRange)
            }
        }

        // Bold **text**
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            let matches = boldRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let contentRange = match.range(at: 1)
                attributed.addAttributes([
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
                ], range: contentRange)
            }
        }

        // Italic _text_ or *text*
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)|_(.+?)_", options: []) {
            let matches = italicRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                for index in 1..<match.numberOfRanges {
                    let range = match.range(at: index)
                    if range.location != NSNotFound {
                        attributed.addAttributes([
                            .font: UIFont.italicSystemFont(ofSize: 18)
                        ], range: range)
                    }
                }
            }
        }

        // Inline code `code`
        if let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            let matches = codeRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let contentRange = match.range(at: 1)
                attributed.addAttributes([
                    .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular),
                    .foregroundColor: UIColor.systemOrange
                ], range: contentRange)
                // Dim the surrounding backticks
                attributed.addAttributes([
                    .foregroundColor: UIColor.secondaryLabel
                ], range: match.range(at: 0))
            }
        }

        // Bulleted lists - adjust indentation
        if let bulletRegex = try? NSRegularExpression(pattern: "^(\\s*)([-*])\\s+", options: [.anchorsMatchLines]) {
            let matches = bulletRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let bulletRange = match.range(at: 2)
                let paragraphRange = (text as NSString).lineRange(for: match.range(at: 0))
                let paragraph = NSMutableParagraphStyle()
                paragraph.headIndent = 16
                paragraph.firstLineHeadIndent = 0
                paragraph.paragraphSpacing = 8
                attributed.addAttributes([
                    .paragraphStyle: paragraph
                ], range: paragraphRange)
                attributed.addAttributes([
                    .foregroundColor: UIColor.secondaryLabel
                ], range: bulletRange)
            }
        }

        return attributed
    }

}
