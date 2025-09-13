import SwiftUI

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: CGFloat = 0
    @State private var morphPhase: CGFloat = 0
    
    let configuration: Configuration
    
    struct Configuration {
        var baseHue: CGFloat?
        var saturation: CGFloat = 0.65
        var complexity: Int = 4
        var animationSpeed: Double = 0.8
        var blurIntensity: CGFloat = 0.3
        var interactive: Bool = false
    }
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { _ in
            Canvas { ctx, size in
                let baseHue = configuration.baseHue ?? (scheme == .dark ? 0.60 : 0.15)
                // Performance/adaptivity guards
                let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                let effectiveComplexity = max(1, min(configuration.complexity, (reduceMotion || lowPower) ? 2 : configuration.complexity))
                let effectiveSpeed = (reduceMotion || lowPower) ? 0.2 * configuration.animationSpeed : configuration.animationSpeed
                let effectiveBlur = (reduceMotion || lowPower) ? configuration.blurIntensity * 0.5 : configuration.blurIntensity

                let colors = generateColors(baseHue: baseHue, count: effectiveComplexity)
                let w = size.width, h = size.height
                let maxRadius = min(w, h) * 0.4
                
                for (i, color) in colors.enumerated() {
                    let layerTime = t + CGFloat(i) * 1.2
                    let morphOffset = morphPhase + CGFloat(i) * 0.3
                    
                    var shape = Path()
                    
                    for j in 0..<effectiveComplexity {
                        let subPhase = layerTime + CGFloat(j) * 0.5
                        let radius = maxRadius * (0.6 + 0.4 * sin(morphOffset + CGFloat(j)))
                        
                        let x = w * (0.5 + 0.3 * sin(subPhase * effectiveSpeed))
                        let y = h * (0.5 + 0.3 * cos(subPhase * effectiveSpeed * 1.2))
                        
                        if j == 0 {
                            shape.addEllipse(in: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            ))
                        } else {
                            shape.addRoundedRect(
                                in: CGRect(
                                    x: x - radius,
                                    y: y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                ),
                                cornerSize: CGSize(width: radius * 0.5, height: radius * 0.5)
                            )
                        }
                    }
                    
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: maxRadius * effectiveBlur))
                        layer.addFilter(.alphaThreshold(min: 0.15))
                        layer.opacity = 0.8
                        layer.fill(shape, with: .color(color))
                    }
                }
                
                ctx.drawLayer { layer in
                    let gradient = Gradient(colors: [
                        .clear,
                        Color(white: 1, opacity: 0.03),
                        .clear
                    ])
                    layer.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: w, y: h)
                        )
                    )
                }
            }
            .background(Material.thin)
            .ignoresSafeArea()
            .onAppear {
                let baseTDuration = (reduceMotion ? 16.0 : 8.0)
                let baseMorphDuration = (reduceMotion ? 24.0 : 12.0)
                withAnimation(.linear(duration: baseTDuration).repeatForever(autoreverses: false)) {
                    t = .pi * 2
                }
                withAnimation(.easeInOut(duration: baseMorphDuration).repeatForever(autoreverses: true)) {
                    morphPhase = .pi * 2
                }
            }
        }
        .compositingGroup()
        .luminanceToAlpha()
        .blendMode(.normal)
    }
    
    private func generateColors(baseHue: CGFloat, count: Int? = nil) -> [Color] {
        let count = count ?? configuration.complexity
        return (0..<count).map { i in
            let hueOffset = CGFloat(i) * 0.06
            let hue = baseHue + hueOffset
            return Color(
                hue: hue.truncatingRemainder(dividingBy: 1),
                saturation: configuration.saturation * (0.8 + 0.2 * sin(CGFloat(i))),
                brightness: 0.95,
                opacity: 0.35 / CGFloat(i + 1)
            )
        }
    }
}

struct LiquidGlassBackgroundModifier: ViewModifier {
    let configuration: LiquidGlassBackground.Configuration
    
    func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(configuration: configuration)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func liquidGlassBackground(
        baseHue: CGFloat? = nil,
        complexity: Int = 4,
        animationSpeed: Double = 0.8,
        blurIntensity: CGFloat = 0.3
    ) -> some View {
        modifier(LiquidGlassBackgroundModifier(
            configuration: .init(
                baseHue: baseHue,
                complexity: complexity,
                animationSpeed: animationSpeed,
                blurIntensity: blurIntensity
            )
        ))
    }
}
