import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Animated glass navigation bar that shrinks to Dynamic Island on scroll
struct AnimatedGlassNavigationBar<Trailing: View>: View {
    @Environment(\.tokens) private var T
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var activeScreenBounds: CGRect = .zero

    let title: String
    let showBack: Bool
    let onBack: (() -> Void)?
    let trailing: Trailing
    let scrollOffset: CGFloat // Negative when scrolling down
    
    // Animation thresholds
    private let startShrinkOffset: CGFloat = -20
    private let fullCollapseOffset: CGFloat = -120
    
    // Dynamic sizing based on device
    private var dynamicIslandHeight: CGFloat {
        // Adapt to device size classes
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 52 // iPad
        }
        return 44 // iPhone
    }
    
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
        let screenWidth = currentScreenWidth
        let horizontalPadding: CGFloat = 40
        let fullWidth = max(0, screenWidth - horizontalPadding)
        
        // Scale collapsed width based on screen size
        let minCollapsedWidth: CGFloat = 120
        let collapsedRatio: CGFloat = horizontalSizeClass == .regular ? 0.35 : 0.45
        let collapsedWidth = min(max(minCollapsedWidth, screenWidth * collapsedRatio), fullWidth)
        
        return lerp(fullWidth, collapsedWidth, collapseProgress)
    }

    private var collapsedIslandWidth: CGFloat {
        let screenWidth = currentScreenWidth
        let minCollapsedWidth: CGFloat = 120
        let collapsedRatio: CGFloat = horizontalSizeClass == .regular ? 0.35 : 0.45
        return max(minCollapsedWidth, screenWidth * collapsedRatio)
    }

    private var currentScreenWidth: CGFloat {
        if activeScreenBounds.width > 0 {
            return activeScreenBounds.width
        }
        return Self.primarySceneBounds()?.width ?? 0
    }

    private var contentInsets: EdgeInsets {
        EdgeInsets(
            top: lerp(18, 8, collapseProgress),
            leading: lerp(20, 12, collapseProgress),
            bottom: lerp(18, 8, collapseProgress),
            trailing: lerp(20, 12, collapseProgress)
        )
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
        // Adapt offset based on device safe area and size class
        let baseSafeArea: CGFloat = verticalSizeClass == .regular && horizontalSizeClass == .regular ? 24 : 59
        let targetOffset: CGFloat = -baseSafeArea + 8
        return targetOffset * collapseProgress
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
                    padding: contentInsets,
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
                    .frame(width: collapsedIslandWidth, height: dynamicIslandHeight)
                    .offset(y: verticalOffset)
                    .opacity((collapseProgress - 0.8) / 0.2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0), value: collapseProgress)
        .background(
            WindowScreenObserver { screen in
                let bounds = screen.bounds
                if activeScreenBounds != bounds {
                    activeScreenBounds = bounds
                }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        )
    }
}

private extension AnimatedGlassNavigationBar {
    func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    static func primarySceneBounds() -> CGRect? {
#if canImport(UIKit)
        func connectedWindowScenes() -> [UIWindowScene] {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
        }

        let scenes: [UIWindowScene]
        if Thread.isMainThread {
            scenes = connectedWindowScenes()
        } else {
            var fetched: [UIWindowScene] = []
            DispatchQueue.main.sync {
                fetched = connectedWindowScenes()
            }
            scenes = fetched
        }

        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return active.screen.bounds
        }

        if let foregroundInactive = scenes.first(where: { $0.activationState == .foregroundInactive }) {
            return foregroundInactive.screen.bounds
        }

        return scenes.first?.screen.bounds
#else
        return nil
#endif
    }
}

#if canImport(UIKit)
struct WindowScreenObserver: UIViewRepresentable {
    let onScreenChange: (UIScreen) -> Void

    func makeUIView(context: Context) -> WindowScreenObserverView {
        let view = WindowScreenObserverView()
        view.onScreenChange = onScreenChange
        return view
    }

    func updateUIView(_ uiView: WindowScreenObserverView, context: Context) {
        uiView.onScreenChange = onScreenChange
        uiView.notifyIfNeeded()
    }
}
final class WindowScreenObserverView: UIView {
    var onScreenChange: ((UIScreen) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        notifyIfNeeded()
    }

    func notifyIfNeeded() {
        guard let screen = window?.windowScene?.screen else { return }
        onScreenChange?(screen)
    }
}
#endif

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
