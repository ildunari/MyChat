import SwiftUI
#if canImport(MarkdownUI)
import MarkdownUI
#endif

enum ChatStyle {
    static let bubbleCorner: CGFloat = 16
}

#if canImport(MarkdownUI)
extension Theme {
    // Dynamic MarkdownUI theme that honors our ThemeTokens
    static func chatApp(_ T: ThemeTokens) -> Theme {
        Theme.gitHub
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.95))
                BackgroundColor(T.codeBg)
            }
            .strong { FontWeight(.semibold) }
            .link { ForegroundColor(T.link) }
            .paragraph { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.18))
                    .markdownMargin(top: 0, bottom: 8)
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.1))
            }
    }
}
#endif
