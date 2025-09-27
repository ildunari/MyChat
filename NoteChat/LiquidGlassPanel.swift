import SwiftUI

/// Glass-styled container for panels and drawers, with a fallback for reduced transparency.
struct LiquidGlassPanel<Content: View>: View {
    @Environment(\.tokens) private var T
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let cornerRadius: CGFloat
    private let padding: EdgeInsets
    private let shadowRadius: CGFloat
    private let shadowOpacity: Double
    private let content: Content

    init(cornerRadius: CGFloat = 24,
         padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
         shadowRadius: CGFloat = 18,
         shadowOpacity: Double = 0.22,
         @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let borderColor = T.borderSoft.opacity(scheme == .dark ? 0.55 : 0.38)
        let tintOpacity = scheme == .dark ? 0.28 : 0.20

        let fallbackFill: AnyShapeStyle = reduceTransparency
            ? AnyShapeStyle(T.surfaceElevated.opacity(scheme == .dark ? 0.85 : 0.82))
            : AnyShapeStyle(.ultraThinMaterial)

        let panel = Group {
            if #available(iOS 18.0, *), reduceTransparency == false {
                GlassEffectContainer(spacing: 0) {
                    content
                        .padding(padding)
                        .glassEffect(
                            .regular
                                .tint(T.accent.opacity(tintOpacity))
                                .interactive(),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                }
            } else {
                content
                    .padding(padding)
                    .background(
                        shape
                            .fill(fallbackFill)
                    )
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(borderColor, lineWidth: 0.9))

        return panel
            .shadow(
                color: shadowRadius <= 0 ? .clear : T.shadow.opacity(shadowOpacity),
                radius: shadowRadius,
                y: shadowRadius > 0 ? shadowRadius * 0.55 : 0
            )
    }
}


