import SwiftUI

/// Wraps content with the application's theme and appearance settings.
struct AppThemeView<Content: View>: View {
    @Environment(\.colorScheme) private var systemScheme
    @Environment(SettingsStore.self) private var settings
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let scheme = effectiveColorScheme() ?? systemScheme
        let tokens = ThemeFactory.make(style: themeStyle(), colorScheme: scheme)
        content()
            .theme(tokens)
            .tint(tokens.accent)
            .fontDesign(fontDesignFromSettings())
            .dynamicTypeSize(dynamicTypeFromSettings())
            .preferredColorScheme(effectiveColorScheme())
            .background(tokens.bg.ignoresSafeArea())
    }

    // MARK: - Helpers
    private func themeStyle() -> AppThemeStyle {
        switch settings.chatBubbleColorID.lowercased() {
        case "slate", "coolslate": return .coolSlate
        case "sand", "sun", "sunset": return .sand
        case "lavender", "purple": return .lavender
        case "contrast", "highcontrast", "hc": return .highContrast
        default: return .coolSlate
        }
    }

    private func effectiveColorScheme() -> ColorScheme? {
        switch settings.interfaceTheme.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func fontDesignFromSettings() -> Font.Design {
        switch settings.interfaceFontStyle {
        case "serif": return .serif
        case "rounded": return .rounded
        case "mono": return .monospaced
        default: return .default
        }
    }

    private func dynamicTypeFromSettings() -> DynamicTypeSize {
        switch settings.interfaceTextSizeIndex {
        case 0: return .xSmall
        case 1: return .small
        case 2: return .medium
        case 3: return .large
        default: return .xLarge
        }
    }
}
