import Foundation
import SwiftUI

#if canImport(Highlightr)
import Highlightr
#endif

enum CodeHighlightBridge {
    private static let worker = CodeHighlightWorker()

    static func highlight(_ code: String, language: String?, colorScheme: ColorScheme) async -> AttributedString {
        await worker.highlight(code: code, language: language, appearance: colorScheme)
    }
}

private actor CodeHighlightWorker {
    private var cache: [CacheKey: AttributedString] = [:]

    func highlight(code: String, language: String?, appearance: ColorScheme) async -> AttributedString {
        let lang = language?.lowercased() ?? ""
        let key = CacheKey(code: code, language: lang, appearance: appearance == .dark ? "dark" : "light")
        if let cached = cache[key] {
            return cached
        }

        let rendered: AttributedString
        #if canImport(Highlightr)
        rendered = await highlightWithHighlightr(code: code, language: lang, appearance: appearance)
        #else
        rendered = AttributedString(code)
        #endif
        cache[key] = rendered
        return rendered
    }

    #if canImport(Highlightr)
    private func highlightWithHighlightr(code: String, language: String, appearance: ColorScheme) async -> AttributedString {
        await Task.detached(priority: .userInitiated) { () -> AttributedString in
            guard let highlightr = Highlightr() else {
                return AttributedString(code)
            }
            let themeName = CodeTheme.current(for: appearance)
            _ = highlightr.setTheme(to: themeName)
            let highlighted = highlightr.highlight(code, as: language.isEmpty ? nil : language)
            return AttributedString(highlighted ?? NSAttributedString(string: code))
        }.value
    }
    #endif

    private struct CacheKey: Hashable {
        let digest: Int
        let length: Int
        let language: String
        let appearance: String

        init(code: String, language: String, appearance: String) {
            var hasher = Hasher()
            hasher.combine(code)
            hasher.combine(language)
            hasher.combine(appearance)
            self.digest = hasher.finalize()
            self.length = code.count
            self.language = language
            self.appearance = appearance
        }
    }
}
