import SwiftUI

enum AppThemeStyle: String, CaseIterable, Identifiable {
    case terracotta, sand, coolSlate, lavender, highContrast
    var id: String { rawValue }
}

struct ThemeTokens {
    let bg: Color
    let surface: Color
    let surfaceElevated: Color
    let borderSoft: Color
    let borderHard: Color

    let text: Color
    let textSecondary: Color
    let link: Color
    let codeBg: Color

    let accent: Color
    let accentSoft: Color

    let bubbleUser: Color
    let bubbleAssistant: Color
    let bubbleTool: Color

    let shadow: Color

    let radiusSmall: CGFloat
    let radiusMedium: CGFloat
    let radiusLarge: CGFloat
}

struct ThemeFactory {
    static func make(style: AppThemeStyle, colorScheme: ColorScheme) -> ThemeTokens {
        let paper      = Color(red: 0.97, green: 0.96, blue: 0.93)
        let paperDark  = Color(red: 0.10, green: 0.10, blue: 0.10)

        let terra      = Color(red: 0.85, green: 0.47, blue: 0.36)   // soft terracotta
        let sandLight  = Color(red: 0.94, green: 0.82, blue: 0.58)   // pastel sand (Claude-adjacent)
        let sandDeep   = Color(red: 0.86, green: 0.70, blue: 0.40)
        let slate      = Color(red: 0.22, green: 0.33, blue: 0.43)   // cool slate
        let lavender   = Color(red: 0.47, green: 0.45, blue: 0.65)   // muted lavender

        let isDark = (colorScheme == .dark)

        let accent: Color
        let accentSoft: Color
        switch style {
        case .terracotta:   accent = terra;                             accentSoft = terra.opacity(0.14)
        case .sand:         accent = isDark ? sandDeep : sandLight;     accentSoft = accent.opacity(0.20)
        case .coolSlate:    accent = slate;                             accentSoft = slate.opacity(0.14)
        case .lavender:     accent = lavender;                          accentSoft = lavender.opacity(0.14)
        case .highContrast: accent = .orange;                           accentSoft = Color.orange.opacity(0.20)
        }

        return ThemeTokens(
            bg: isDark ? paperDark : paper,
            surface: isDark ? Color(red: 0.13, green: 0.13, blue: 0.13) : Color.white.opacity(0.86),
            surfaceElevated: isDark ? Color(red: 0.16, green: 0.16, blue: 0.16) : Color.white,
            borderSoft: isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
            borderHard: isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10),
            text: isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.90),
            textSecondary: isDark ? Color.white.opacity(0.70) : Color.black.opacity(0.60),
            link: isDark ? accent.opacity(0.9) : accent,
            codeBg: isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03),
            accent: accent,
            accentSoft: accentSoft,
            bubbleUser: isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.035),
            bubbleAssistant: isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.02),
            bubbleTool: isDark ? Color.white.opacity(0.07) : accentSoft,
            shadow: isDark ? Color.black.opacity(0.60) : Color.black.opacity(0.10),
            radiusSmall: 10, radiusMedium: 14, radiusLarge: 20
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeFactory.make(style: .terracotta, colorScheme: .light)
}
extension EnvironmentValues {
    var tokens: ThemeTokens {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
extension View {
    func theme(_ tokens: ThemeTokens) -> some View { environment(\.tokens, tokens) }
}
