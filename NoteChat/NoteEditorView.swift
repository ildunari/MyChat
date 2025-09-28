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
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.textColor = UIColor.label
        view.adjustsFontForContentSizeCategory = true
        view.isEditable = true
        view.isScrollEnabled = true
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 40, right: 0)
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if state.text.isEmpty {
            view.text = placeholder
            view.textColor = UIColor.secondaryLabel
        } else {
            view.text = state.text
        }
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isUpdatingFromState = true
        if state.text.isEmpty {
            if uiView.text != placeholder {
                uiView.text = placeholder
                uiView.textColor = UIColor.secondaryLabel
            }
        } else {
            if uiView.text != state.text {
                uiView.text = state.text
                uiView.textColor = UIColor.label
            }
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

        init(state: NoteEditorState, onTextChange: @escaping (String) -> Void, onSelectionChange: @escaping (NSRange) -> Void) {
            self.state = state
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.secondaryLabel {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            let newText = textView.text ?? ""
            state.text = newText
            onTextChange(newText)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            state.selectedRange = textView.selectedRange
            onSelectionChange(textView.selectedRange)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard isUpdatingFromState == false else { return }
            if textView.text?.isEmpty ?? true {
                textView.text = ""
                onTextChange("")
            }
        }
    }
}
