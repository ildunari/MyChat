import SwiftUI
import MarkdownUI

struct AIResponseView: View {
    enum Content {
        case staticText(String)
        case streaming(StreamingMarkdownSnapshot)
    }

    let content: Content

    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    init(text: String) {
        self.content = .staticText(text)
    }

    init(streaming snapshot: StreamingMarkdownSnapshot) {
        self.content = .streaming(snapshot)
    }

    var body: some View {
        Group {
            switch content {
            case .staticText(let text):
                StreamingMarkdownView(snapshot: snapshot(for: text), isStreaming: false)
            case .streaming(let snapshot):
                StreamingMarkdownView(snapshot: snapshot, isStreaming: true)
            }
        }
        .padding(.vertical, 2)
        .tint(tokens.link)
    }

    private func snapshot(for text: String) -> StreamingMarkdownSnapshot {
        var buffer = StreamingMarkdownBuffer()
        buffer.replaceAll(with: text)
        
        // For static messages, flush tail to stable since there's no more streaming
        buffer.flushTail()
        
        #if DEBUG
        print("📊 AIResponseView snapshot:")
        print("  Input length: \(text.count)")
        print("  Stable length: \(buffer.stableMarkdown.count)")
        print("  Tail length: \(buffer.tailRaw.count)")
        if !buffer.tailRaw.isEmpty {
            print("  ⚠️ Tail contains: \(buffer.tailRaw.prefix(100))")
            print("  Tail state: \(buffer.tailState)")
        }
        #endif
        
        return StreamingMarkdownSnapshot(stableMarkdown: buffer.stableMarkdown,
                                         tailRaw: buffer.tailRaw,
                                         tailState: buffer.tailState,
                                         reasoningSummary: "")
    }
}
