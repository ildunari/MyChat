import Combine
import SwiftUI

/// Shared controller that coordinates the dock's expanded/collapsed presentation.
@MainActor
final class DockController: ObservableObject {
    /// 0 = fully expanded, 1 = fully collapsed.
    @Published private(set) var collapseProgress: CGFloat = 0

    /// When `true`, the dock is effectively collapsed to the arrow strip.
    @Published private(set) var isCollapsed: Bool = false

    static let collapseDistance: CGFloat = 120

    var expandedHeight: CGFloat { DockMetrics.expandedHeight }
    var collapsedHeight: CGFloat { DockMetrics.collapsedHeight }

    var currentHeight: CGFloat {
        lerp(from: expandedHeight, to: collapsedHeight, progress: collapseProgress)
    }

    func update(progress rawValue: CGFloat, animated: Bool) {
        let clamped = rawValue.clamped(to: 0...1)
        withOptionalAnimation(animated) {
            collapseProgress = clamped
            isCollapsed = clamped >= 0.98
        }
    }

    func setCollapsed(_ collapsed: Bool, animated: Bool) {
        update(progress: collapsed ? 1 : 0, animated: animated)
    }

    func nudge(withScrollOffset offset: CGFloat) {
        guard offset.isFinite else { return }
        let progress = min(max(offset / Self.collapseDistance, 0), 1)
        update(progress: progress, animated: true)
    }

    func expand(animated: Bool = true) { setCollapsed(false, animated: animated) }
    func collapse(animated: Bool = true) { setCollapsed(true, animated: animated) }

    private func lerp(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func withOptionalAnimation(_ animated: Bool, _ updates: () -> Void) {
        if animated { withAnimation(.easeInOut(duration: 0.22), updates) } else { updates() }
    }
}

private extension Comparable where Self: Strideable, Stride: SignedNumeric {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
