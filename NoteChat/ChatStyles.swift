import SwiftUI

enum ChatStyle {
    static let bubbleCorner: CGFloat = 18
    static let bubbleGlassIntensity: CGFloat = 0.8
    static let bubbleBlur: CGFloat = 12
}

/// Highlight.js theme names used for syntax highlighting
enum CodeTheme {
    /// Theme optimized for light interface style
    static let light = "xcode"
    /// Theme optimized for dark interface style
    static let dark = "atom-one-dark"

    static func current(for colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? dark : light
    }
}

// MARK: - Liquid Glass Chat Bubble Style
struct LiquidGlassChatBubbleStyle: ViewModifier {
    let isUser: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if reduceTransparency {
                    // Accessibility fallback
                    RoundedRectangle(cornerRadius: ChatStyle.bubbleCorner, style: .continuous)
                        .fill(isUser ? Color.accentColor : (scheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)))
                } else {
                    // Liquid glass effect
                    ZStack {
                        // Base glass layer
                        RoundedRectangle(cornerRadius: ChatStyle.bubbleCorner, style: .continuous)
                            .fill(isUser ? Material.thick : Material.regular)
                            .overlay {
                                // Color tint overlay
                                RoundedRectangle(cornerRadius: ChatStyle.bubbleCorner, style: .continuous)
                                    .fill(
                                        isUser 
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.primary.opacity(0.02)
                                    )
                            }
                        
                        // Gradient shimmer
                        RoundedRectangle(cornerRadius: ChatStyle.bubbleCorner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isUser ? 0.2 : 0.1),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Subtle border
                        RoundedRectangle(cornerRadius: ChatStyle.bubbleCorner, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(scheme == .dark ? 0.1 : 0.2),
                                lineWidth: 0.5
                            )
                    }
                }
            }
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.3 : 0.1),
                radius: isUser ? 8 : 6,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

extension View {
    func liquidGlassChatBubble(isUser: Bool) -> some View {
        modifier(LiquidGlassChatBubbleStyle(isUser: isUser))
    }
}

// MARK: - Liquid Glass Toolbar Button Style
struct LiquidGlassToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if configuration.isPressed {
                    Capsule()
                        .fill(Material.thin)
                        .overlay {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.1))
                        }
                } else {
                    Capsule()
                        .fill(Material.ultraThin)
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(scheme == .dark ? 0.1 : 0.15),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidGlassToolbarButtonStyle {
    static var liquidGlassToolbar: LiquidGlassToolbarButtonStyle {
        LiquidGlassToolbarButtonStyle()
    }
}

