import UIKit
import Down

enum MarkdownStylerFactory {
    static func styler(textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor) -> DownStyler {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let monospaceBase = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.monospaced) ?? baseFont.fontDescriptor

        var fonts = StaticFontCollection()
        fonts.heading1 = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 32, weight: .bold))
        fonts.heading2 = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 26, weight: .semibold))
        fonts.heading3 = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold))
        fonts.heading4 = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 19, weight: .semibold))
        fonts.heading5 = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        fonts.heading6 = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        fonts.body = baseFont
        fonts.code = UIFont(descriptor: monospaceBase, size: 0)
        fonts.listItemPrefix = UIFont(descriptor: monospaceBase, size: 0)

        var colors = StaticColorCollection()
        colors.heading1 = textColor
        colors.heading2 = textColor
        colors.heading3 = textColor
        colors.heading4 = textColor
        colors.heading5 = textColor
        colors.heading6 = textColor
        colors.body = textColor
        colors.code = textColor
        colors.link = accentColor
        colors.quote = secondaryTextColor
        colors.quoteStripe = secondaryTextColor.withAlphaComponent(0.25)
        colors.thematicBreak = secondaryTextColor.withAlphaComponent(0.3)
        colors.listItemPrefix = secondaryTextColor
        colors.codeBlockBackground = secondaryTextColor.withAlphaComponent(0.12)

        let paragraphSpacing: CGFloat = 10
        let headingStyle = NSMutableParagraphStyle().configured(lineSpacing: 4, spacingAfter: paragraphSpacing)
        var paragraphs = StaticParagraphStyleCollection()
        paragraphs.heading1 = headingStyle
        paragraphs.heading2 = headingStyle
        paragraphs.heading3 = NSMutableParagraphStyle().configured(lineSpacing: 3, spacingAfter: paragraphSpacing)
        paragraphs.heading4 = NSMutableParagraphStyle().configured(lineSpacing: 3, spacingAfter: paragraphSpacing)
        paragraphs.heading5 = NSMutableParagraphStyle().configured(lineSpacing: 2, spacingAfter: paragraphSpacing)
        paragraphs.heading6 = NSMutableParagraphStyle().configured(lineSpacing: 2, spacingAfter: paragraphSpacing / 1.5)

        let bodyStyle = NSMutableParagraphStyle().configured(lineSpacing: 2, spacingAfter: 6)
        paragraphs.body = bodyStyle
        paragraphs.code = NSMutableParagraphStyle().configured(lineSpacing: 2, spacingAfter: 10, inset: 12)

        var config = DownStylerConfiguration(fonts: fonts, colors: colors, paragraphStyles: paragraphs)
        config.listItemOptions = ListItemOptions(spacingAfterPrefix: 8, spacingAbove: 4, spacingBelow: 8)
        config.quoteStripeOptions = QuoteStripeOptions(thickness: 3, spacingAfter: 12)
        config.thematicBreakOptions = ThematicBreakOptions(thickness: 1.5, indentation: 20)
        config.codeBlockOptions = CodeBlockOptions(containerInset: 12)

        return DownStyler(configuration: config)
    }
}

enum MarkdownStyler {
    static func editorAttributedString(for markdown: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let styler = MarkdownStylerFactory.styler(textColor: UIColor.label,
                                                  secondaryTextColor: UIColor.secondaryLabel,
                                                  accentColor: UIColor.link)
        if let attributed = try? Down(markdownString: markdown).toAttributedString(styler: styler) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            if !baseAttributes.isEmpty {
                mutable.addAttributes(baseAttributes, range: NSRange(location: 0, length: mutable.length))
            }
            return mutable
        }
        return NSAttributedString(string: markdown, attributes: baseAttributes)
    }
}

private extension NSMutableParagraphStyle {
    func configured(lineSpacing: CGFloat, spacingAfter: CGFloat, inset: CGFloat = 0) -> NSMutableParagraphStyle {
        let style = self
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = spacingAfter
        style.headIndent = inset
        style.firstLineHeadIndent = inset
        style.lineBreakMode = .byWordWrapping
        return style
    }
}
