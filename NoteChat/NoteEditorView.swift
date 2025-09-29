import SwiftUI
import Combine
import UIKit

@MainActor
final class NoteEditorState: ObservableObject {
    @Published var text: String
    @Published var selectedRange: NSRange

    init(text: String) {
        self.text = text
        self.selectedRange = NSRange(location: 0, length: 0)
    }
}

struct NoteTextEditor: UIViewRepresentable {
    @ObservedObject var state: NoteEditorState
    var placeholder: String
    var onTextChange: (String) -> Void
    var onSelectionChange: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, onTextChange: onTextChange, onSelectionChange: onSelectionChange)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.adjustsFontForContentSizeCategory = true
        view.isEditable = true
        view.isScrollEnabled = true
        view.keyboardDismissMode = .interactive
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let baseAttributes = context.coordinator.baseAttributes
        if state.text.isEmpty {
            view.text = placeholder
            view.textColor = UIColor.secondaryLabel
        } else {
            view.attributedText = MarkdownStyler.editorAttributedString(for: state.text, baseAttributes: baseAttributes)
            view.textColor = UIColor.label
        }
        view.typingAttributes = baseAttributes
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isUpdatingFromState = true
        if state.text.isEmpty {
            if uiView.text != placeholder {
                uiView.text = placeholder
                uiView.textColor = UIColor.secondaryLabel
                uiView.typingAttributes = context.coordinator.baseAttributes
            }
        } else {
            context.coordinator.applyMarkdownStyling(to: uiView, text: state.text)
        }

        if uiView.selectedRange != state.selectedRange {
            uiView.selectedRange = state.selectedRange
        }
        context.coordinator.isUpdatingFromState = false
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var isUpdatingFromState = false
        private let state: NoteEditorState
        private let onTextChange: (String) -> Void
        private let onSelectionChange: (NSRange) -> Void

        fileprivate var baseAttributes: [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 6
            paragraph.paragraphSpacing = 12
            paragraph.hyphenationFactor = 0.3

            let font = UIFontMetrics(forTextStyle: .body)
                .scaledFont(for: UIFont.systemFont(ofSize: 18, weight: .regular))

            return [
                .font: font,
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor.label
            ]
        }

        init(state: NoteEditorState, onTextChange: @escaping (String) -> Void, onSelectionChange: @escaping (NSRange) -> Void) {
            self.state = state
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.secondaryLabel {
                textView.text = ""
                textView.textColor = UIColor.label
                textView.typingAttributes = baseAttributes
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            let newText = textView.text ?? ""
            state.text = newText
            onTextChange(newText)
            applyMarkdownStyling(to: textView, text: newText)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            let selection = textView.selectedRange
            state.selectedRange = selection
            onSelectionChange(selection)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            if textView.text?.isEmpty ?? true {
                textView.text = ""
                onTextChange("")
            }
        }

        func applyMarkdownStyling(to textView: UITextView, text: String) {
            isUpdatingFromState = true
            let selected = textView.selectedRange
            let attributed = MarkdownStyler.editorAttributedString(for: text, baseAttributes: baseAttributes)
            textView.attributedText = attributed
            textView.selectedRange = selected
            textView.typingAttributes = baseAttributes
            isUpdatingFromState = false
        }
    }
}
