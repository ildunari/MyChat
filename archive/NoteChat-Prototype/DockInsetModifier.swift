import SwiftUI

/// A tiny helper to ensure scrollable content never ends up under the custom dock.
/// Usage: attach `.dockBottomInset()` to any `List`, `Form`, or `ScrollView` that
/// is shown within `RootView`. This inserts a clear spacer with the dock height
/// into the bottom safe-area, so nothing is obscured by the dock panel.
extension View {
    func dockBottomInset() -> some View {
        self.safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: DockMetrics.height)
                .accessibilityHidden(true)
        }
    }
}

