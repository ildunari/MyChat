import SwiftUI

/// Animated glass navigation bar that shrinks to Dynamic Island on scroll
struct AnimatedGlassNavigationBar<Trailing: View>: View {
    @Environment(\.tokens) private var T
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    let title: String
    let showBack: Bool
    let onBack: (() -> Void)?
    let trailing: Trailing
    let scrollOffset: CGFloat // Negative when scrolling down
    
    // Animation thresholds
    private let startShrinkOffset: CGFloat = -20
    private let fullCollapseOffset: CGFloat = -120
    private let dynamicIslandHeight: CGFloat = 44 // iPhone Dynamic Island height
    
    // Compute animation progress (0 = fully visible, 1 = collapsed to island)
    private var collapseProgress: CGFloat {
        if scrollOffset >= startShrinkOffset {
            return 0
        } else if scrollOffset <= fullCollapseOffset {
            return 1
        } else {
            let range = fullCollapseOffset - startShrinkOffset
            let progress = (scrollOffset - startShrinkOffset) / range
            return min(1, max(0, progress))
        }
    }
    
    // Animated values
    private var barHeight: CGFloat {
        let fullHeight: CGFloat = 74
        let collapsedHeight: CGFloat = dynamicIslandHeight
        return fullHeight + (collapsedHeight - fullHeight) * collapseProgress
    }
    
    private var barWidth: CGFloat {
        // Get screen width more safely
        let screenWidth: CGFloat = 440 // Default iPhone width, will be overridden by GeometryReader
        let fullWidth = screenWidth - 40 // 20 padding on each side
        let collapsedWidth: CGFloat = 150 // Dynamic Island width
        return fullWidth + (collapsedWidth - fullWidth) * collapseProgress
    }
    
    private var cornerRadius: CGFloat {
        let fullRadius: CGFloat = 22
        let collapsedRadius: CGFloat = 22 // Match Dynamic Island radius
        return fullRadius + (collapsedRadius - fullRadius) * collapseProgress
    }
    
    private var contentOpacity: CGFloat {
        // Fade out content quickly as we collapse
        if collapseProgress < 0.3 {
            return 1
        } else if collapseProgress > 0.7 {
            return 0
        } else {
            return 1 - ((collapseProgress - 0.3) / 0.4)
        }
    }
    
    private var verticalOffset: CGFloat {
        // Move up towards the Dynamic Island position
        // Standard Dynamic Island is about 59pt from top on Pro models
        let topSafeArea: CGFloat = 59
        
        // Dynamic Island is approximately at y: -8 from safe area top
        let targetOffset: CGFloat = -topSafeArea + 8
        return targetOffset * collapseProgress
    }
    
    private var horizontalPadding: CGFloat {
        let fullPadding: EdgeInsets = EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
        let collapsedPadding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        
        let leading = fullPadding.leading + (collapsedPadding.leading - fullPadding.leading) * collapseProgress
        return leading
    }
    
    private var shadowOpacity: CGFloat {
        0.28 * (1 - collapseProgress)
    }
    
    init(title: String,
         showBack: Bool = false,
         scrollOffset: CGFloat = 0,
         onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showBack = showBack
        self.scrollOffset = scrollOffset
        self.onBack = onBack
        self.trailing = trailing()
    }
    
    init(title: String,
         showBack: Bool = false,
         scrollOffset: CGFloat = 0,
         onBack: (() -> Void)? = nil) where Trailing == EmptyView {
        self.init(title: title, showBack: showBack, scrollOffset: scrollOffset, onBack: onBack) {
            EmptyView()
        }
    }
    
    var body: some View {
        ZStack {
            // Background blur effect
            if collapseProgress < 0.99 {
                LiquidGlassPanel(
                    cornerRadius: cornerRadius,
                    padding: EdgeInsets(
                        top: horizontalPadding,
                        leading: horizontalPadding,
                        bottom: horizontalPadding,
                        trailing: horizontalPadding
                    ),
                    shadowRadius: 16,
                    shadowOpacity: shadowOpacity
                ) {
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
                            .opacity(contentOpacity)
                            .scaleEffect(1 - collapseProgress * 0.3)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(T.text)
                                .lineLimit(1)
                        }
                        .opacity(contentOpacity)
                        .scaleEffect(1 - collapseProgress * 0.4)
                        
                        Spacer(minLength: 16)
                        
                        trailing
                            .frame(maxHeight: .infinity, alignment: .center)
                            .opacity(contentOpacity)
                            .scaleEffect(1 - collapseProgress * 0.3)
                    }
                }
                .frame(width: barWidth, height: barHeight)
                .offset(y: verticalOffset)
            }
            
            // Dynamic Island placeholder when fully collapsed
            if collapseProgress > 0.8 {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.black)
                    .frame(width: 150, height: dynamicIslandHeight)
                    .offset(y: verticalOffset)
                    .opacity((collapseProgress - 0.8) / 0.2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0), value: collapseProgress)
    }
}

// MARK: - Scroll Offset Tracker

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

extension View {
    func trackScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        modifier(ScrollOffsetModifier(offset: offset))
    }
}