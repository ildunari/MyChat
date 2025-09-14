import SwiftUI
import UIKit

enum AppThemeStyle: String, CaseIterable, Identifiable {
    // Legacy styles (kept for backward compatibility)
    case terracotta, sand, coolSlate, lavender, highContrast, ocean, forest
    // New SevenThemes styles
    case aqua, cobalt, cocoa, indigo, saffron, teal
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
        let isDark = (colorScheme == .dark)

        // Try SevenThemes asset-based palettes first when selected
        if let fromAssets = tokensFromSevenThemes(style: style, colorScheme: colorScheme) {
            return fromAssets
        }

        // Palette anchors
        let terra      = Color(red: 0.86, green: 0.45, blue: 0.36)
        let sandLight  = Color(red: 0.94, green: 0.84, blue: 0.62)
        let sandDeep   = Color(red: 0.86, green: 0.70, blue: 0.40)
        let slate      = Color(red: 0.20, green: 0.32, blue: 0.50)
        let lavender   = Color(red: 0.52, green: 0.48, blue: 0.68)
        let ocean      = Color(red: 0.06, green: 0.60, blue: 0.65)
        let forest     = Color(red: 0.17, green: 0.56, blue: 0.37)

        // Compute palette-specific backgrounds and surfaces
        func palette(_ accent: Color, _ tint: Color) -> (bg: Color, surface: Color, elevated: Color, accent: Color, accentSoft: Color) {
            let bg = isDark ? tint.opacity(0.16) : tint.opacity(0.10)
            let surface = isDark ? Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.95) : Color.white.opacity(0.96)
            let elevated = isDark ? Color(red: 0.16, green: 0.16, blue: 0.18) : Color.white
            return (bg: bg, surface: surface, elevated: elevated, accent: accent, accentSoft: accent.opacity(0.18))
        }

        let p: (bg: Color, surface: Color, elevated: Color, accent: Color, accentSoft: Color)
        switch style {
        case .terracotta:   p = palette(terra, Color(red: 0.99, green: 0.95, blue: 0.92))
        case .sand:         p = palette(isDark ? sandDeep : sandLight, Color(red: 0.98, green: 0.95, blue: 0.88))
        case .coolSlate:    p = palette(slate, Color(red: 0.93, green: 0.96, blue: 0.99))
        case .lavender:     p = palette(lavender, Color(red: 0.96, green: 0.94, blue: 0.98))
        case .highContrast: p = palette(.orange, Color(red: 1.00, green: 0.98, blue: 0.92))
        case .ocean:        p = palette(ocean, Color(red: 0.90, green: 0.96, blue: 0.97))
        case .forest:       p = palette(forest, Color(red: 0.92, green: 0.97, blue: 0.93))
        // If a SevenThemes style is chosen but assets missing, fall back to a close legacy palette
        case .aqua, .teal:  p = palette(ocean, Color(red: 0.90, green: 0.96, blue: 0.97))
        case .cobalt, .indigo: p = palette(slate, Color(red: 0.93, green: 0.96, blue: 0.99))
        case .cocoa, .saffron: p = palette(terra, Color(red: 0.99, green: 0.95, blue: 0.92))
        }

        return ThemeTokens(
            bg: p.bg,
            surface: p.surface,
            surfaceElevated: p.elevated,
            borderSoft: isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
            borderHard: isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
            text: isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.92),
            textSecondary: isDark ? Color.white.opacity(0.70) : Color.black.opacity(0.60),
            link: isDark ? p.accent.opacity(0.9) : p.accent,
            codeBg: isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03),
            accent: p.accent,
            accentSoft: p.accentSoft,
            bubbleUser: isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.035),
            bubbleAssistant: isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.02),
            bubbleTool: isDark ? Color.white.opacity(0.07) : p.accentSoft,
            shadow: isDark ? Color.black.opacity(0.60) : Color.black.opacity(0.12),
            radiusSmall: 10, radiusMedium: 14, radiusLarge: 20
        )
    }
}

// MARK: - SevenThemes loader
private extension ThemeFactory {
    static func tokensFromSevenThemes(style: AppThemeStyle, colorScheme: ColorScheme) -> ThemeTokens? {
        let name: String
        switch style {
        case .aqua: name = "Aqua"
        case .cobalt: name = "Cobalt"
        case .cocoa: name = "Cocoa"
        case .forest: name = "Forest"
        case .indigo: name = "Indigo"
        case .saffron: name = "Saffron"
        case .teal: name = "Teal"
        default: return nil
        }

        func col(_ key: String, _ fallback: Color) -> Color {
            if let ui = UIColor(named: "\(name)-\(key)") { return Color(ui) }
            return fallback
        }
        // Required colors. If accent or bg is missing, bail out to legacy
        guard let uiAccent = UIColor(named: "\(name)-Accent"),
              let uiBg = UIColor(named: "\(name)-Bg"),
              let uiSurface = UIColor(named: "\(name)-Surface")
        else { return nil }

        let accent = Color(uiAccent)
        let accentTint = UIColor(named: "\(name)-AccentTint").map(Color.init) ?? accent.opacity(0.18)
        let elevated = UIColor(named: "\(name)-Elevated").map(Color.init) ?? Color.white.opacity(colorScheme == .dark ? 0.07 : 1.0)
        let text = UIColor(named: "\(name)-Text").map(Color.init) ?? (colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.92))
        let textSec = UIColor(named: "\(name)-TextSecondary").map(Color.init) ?? (colorScheme == .dark ? .white.opacity(0.70) : .black.opacity(0.60))
        let separator = UIColor(named: "\(name)-Separator").map(Color.init) ?? (colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.10))

        let bg = Color(uiBg)
        let surface = Color(uiSurface)

        return ThemeTokens(
            bg: bg,
            surface: surface,
            surfaceElevated: elevated,
            borderSoft: separator.opacity(0.6),
            borderHard: separator,
            text: text,
            textSecondary: textSec,
            link: accent,
            codeBg: elevated.opacity(colorScheme == .dark ? 0.9 : 1.0),
            accent: accent,
            accentSoft: accentTint,
            bubbleUser: elevated,
            bubbleAssistant: surface,
            bubbleTool: accentTint,
            shadow: colorScheme == .dark ? Color.black.opacity(0.60) : Color.black.opacity(0.12),
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
