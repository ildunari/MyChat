import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatComposerBridge: ObservableObject {
    @Published var text: String = ""
    @Published var isStreaming: Bool = false
    // Store per-chat drafts
    @Published var drafts: [UUID: String] = [:]

    // If true, the next time a ChatView sets up the bridge,
    // it should immediately trigger onSend() using current `text`.
    @Published var pendingAutoSend: Bool = false

    var onSend: (() -> Void)?
    var onStop: (() -> Void)?
    var onPlus: (() -> Void)?
    var onMic: (() -> Void)?
    var onLive: (() -> Void)?

    func saveDraft(for chatID: UUID) {
        drafts[chatID] = text
    }
    func loadDraft(for chatID: UUID) {
        text = drafts[chatID] ?? ""
    }
}
