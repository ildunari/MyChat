import SwiftUI

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @State private var t: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                let baseHue: CGFloat = scheme == .dark ? 0.60 : 0.12 // indigo vs warm
                let colors: [Color] = [
                    Color(hue: baseHue, saturation: 0.7, brightness: 0.9, opacity: 0.35),
                    Color(hue: baseHue + 0.08, saturation: 0.6, brightness: 0.95, opacity: 0.30),
                    Color(hue: baseHue - 0.08, saturation: 0.65, brightness: 1.0, opacity: 0.28)
                ]

                let w = size.width, h = size.height
                let radius = max(w, h) * 0.35
                let time = t

                for i in 0..<colors.count {
                    var shape = Path()
                    let phase = time + CGFloat(i) * 1.3
                    let x = w * (0.5 + 0.35 * sin(phase * 0.7))
                    let y = h * (0.5 + 0.35 * cos(phase * 0.9))
                    shape.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))

                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: radius * 0.28))
                        layer.addFilter(.alphaThreshold(min: 0.2))
                        layer.fill(shape, with: .color(colors[i]))
                    }
                }
            }
            .background(.thinMaterial)
            .ignoresSafeArea()
            .onAppear { withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { t = 8 } }
        }
        .compositingGroup()
    }
}
