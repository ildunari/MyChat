import SwiftUI

/// Floating glass navigation bar with optional back + trailing actions.
struct GlassNavigationBar<Trailing: View>: View {
    @Environment(\.tokens) private var T
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    enum BarStyle {
        case primary
        case compact

        var cornerRadius: CGFloat {
            switch self {
            case .primary: return 22
            case .compact: return 18
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .primary: return EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
            case .compact: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            }
        }

        var shadow: CGFloat {
            switch self {
            case .primary: return 16
            case .compact: return 12
            }
        }
    }

    private let title: String
    private let showBack: Bool
    private let onBack: (() -> Void)?
    private let trailing: Trailing
    private let style: BarStyle

    init(title: String,
         showBack: Bool = false,
         style: BarStyle = .primary,
         onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showBack = showBack
        self.style = style
        self.onBack = onBack
        self.trailing = trailing()
    }

    init(title: String,
         showBack: Bool = false,
         style: BarStyle = .primary,
         onBack: (() -> Void)? = nil) where Trailing == EmptyView {
        self.init(title: title, showBack: showBack, style: style, onBack: onBack) {
            EmptyView()
        }
    }

    var body: some View {
        LiquidGlassPanel(cornerRadius: style.cornerRadius,
                         padding: style.padding,
                         shadowRadius: style.shadow,
                         shadowOpacity: 0.28) {
            HStack(spacing: 14) {
                if showBack {
                    Button(action: { onBack?() }) {
                        AppIcon.chevronDown(16)
                            .rotationEffect(.degrees(90))
                            .foregroundStyle(T.text)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(T.surfaceElevated.opacity(0.72))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(style == .primary ? .title3.weight(.semibold) : .headline)
                        .foregroundStyle(T.text)
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                trailing
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}


