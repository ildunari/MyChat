import SwiftUI

/// A thin wrapper around the editor used in the Notes feature.
/// - If the SwiftDown package is linked, uses `SwiftDownEditor` for a fast, live-preview Markdown editor.
/// - Otherwise falls back to a plain `TextEditor` so builds remain stable without the package.
struct NoteMarkdownEditor: View {
    @Binding var text: String
    var body: some View {
        Group {
            #if canImport(SwiftDown)
            SwiftDownBasedEditor(text: $text)
            #else
            TextEditor(text: $text)
                .font(.system(.body, design: .rounded))
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if canImport(SwiftDown)
import SwiftDown

private struct SwiftDownBasedEditor: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    var body: some View {
        SwiftDownEditor(text: $text)
            .insetsSize(12)
            .theme((scheme == .dark ? Theme.BuiltIn.defaultDark : Theme.BuiltIn.defaultLight).theme())
    }
}
#endif

