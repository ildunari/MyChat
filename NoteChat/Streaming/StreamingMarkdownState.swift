import Foundation
import Combine
import MarkdownUI

struct StreamingMarkdownSnapshot: Equatable {
    var stableMarkdown: String
    var tailRaw: String
    var tailState: StreamingMarkdownBuffer.TailState
    var reasoningSummary: String

    static let empty = StreamingMarkdownSnapshot(stableMarkdown: "", tailRaw: "", tailState: .init(), reasoningSummary: "")

    var stableContent: MarkdownContent {
        MarkdownContent(stableMarkdown)
    }

    var hasVisibleContent: Bool {
        !stableMarkdown.isEmpty || !tailRaw.isEmpty
    }

    var hasReasoningSummary: Bool {
        reasoningSummary.isEmpty == false
    }
}

@MainActor
final class StreamingMarkdownState: ObservableObject {
    @Published private(set) var snapshot: StreamingMarkdownSnapshot = .empty

    private var buffer = StreamingMarkdownBuffer()
    private var reasoningSummary = ""

    func replaceAll(with text: String) {
        buffer.replaceAll(with: text)
        publish()
    }

    func append(_ delta: String) {
        buffer.append(delta)
        publish()
    }

    func flushTail() {
        buffer.flushTail()
        publish()
    }

    func reset() {
        buffer.reset()
        reasoningSummary = ""
        publish()
    }

    func updateReasoningSummary(_ summary: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != reasoningSummary else { return }
        reasoningSummary = String(trimmed.prefix(480))
        publish()
    }

    var combinedText: String {
        snapshot.stableMarkdown + snapshot.tailRaw
    }

    private func publish() {
        snapshot = StreamingMarkdownSnapshot(stableMarkdown: buffer.stableMarkdown,
                                             tailRaw: buffer.tailRaw,
                                             tailState: buffer.tailState,
                                             reasoningSummary: reasoningSummary)
    }
}
