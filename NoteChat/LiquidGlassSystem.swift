import SwiftUI

// MARK: - Liquid Glass Design System
// Implements Apple's Liquid Glass principles with vibrancy, translucency, and fluid morphing

// MARK: - Material Variants
enum LiquidGlassMaterial {
    case regular      // Standard blur with luminosity adjustment
    case clear        // High translucency for media-rich backgrounds
    case prominent    // Enhanced vibrancy for primary actions
    case subtle       // Minimal effect for secondary elements
    
    var material: Material {
        switch self {
        case .regular: return .regularMaterial
        case .clear: return .thinMaterial
        case .prominent: return .ultraThickMaterial
        case .subtle: return .ultraThinMaterial
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .regular: return 20
        case .clear: return 8
        case .prominent: return 30
        case .subtle: return 12
        }
    }
    
    var opacity: CGFloat {
        switch self {
        case .regular: return 0.85
        case .clear: return 0.6
        case .prominent: return 0.95
        case .subtle: return 0.7
        }
    }
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassModifier: ViewModifier {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    let isInteractive: Bool
    @State private var isPressed = false
    @State private var morphScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    // Fallback for accessibility
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(scheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.9))
                } else {
                    ZStack {
                        // Base glass layer
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(material.material)
                        
                        // Vibrancy overlay
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(scheme == .dark ? 0.15 : 0.25),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Subtle border for depth
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(scheme == .dark ? 0.3 : 0.5),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .scaleEffect(morphScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: morphScale)
                }
            }
            .compositingGroup()
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.1), radius: material.blurRadius / 2, y: 2)
            .scaleEffect(isPressed && isInteractive ? 0.97 : 1.0)
            .onChange(of: isPressed) { _, pressed in
                if isInteractive {
                    morphScale = pressed ? 0.98 : 1.0
                }
            }
    }
}

extension View {
    func liquidGlass(
        _ material: LiquidGlassMaterial = .regular,
        cornerRadius: CGFloat = 16,
        isInteractive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            material: material,
            cornerRadius: cornerRadius,
            isInteractive: isInteractive
        ))
    }
}

// MARK: - Liquid Glass Button Style
struct LiquidGlassButtonStyle: ButtonStyle {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .liquidGlass(material, cornerRadius: cornerRadius, isInteractive: true)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .brightness(isHovered ? 0.05 : 0)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(material: .regular, cornerRadius: 12)
    }
    
    static func liquidGlass(_ material: LiquidGlassMaterial, cornerRadius: CGFloat = 12) -> LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(material: material, cornerRadius: cornerRadius)
    }
}

// MARK: - Liquid Glass Card
struct LiquidGlassCard<Content: View>: View {
    let material: LiquidGlassMaterial
    let content: Content
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    init(material: LiquidGlassMaterial = .regular, @ViewBuilder content: () -> Content) {
        self.material = material
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .liquidGlass(material, cornerRadius: 20)
            .rotation3DEffect(
                .degrees(isDragging ? 5 : 0),
                axis: (x: -dragOffset.height / 50, y: dragOffset.width / 50, z: 0)
            )
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = value.translation
                            isDragging = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            dragOffset = .zero
                            isDragging = false
                        }
                    }
            )
    }
}

// MARK: - Liquid Glass Navigation Bar
struct LiquidGlassNavBar<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Placeholder for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .liquidGlass(.regular, cornerRadius: 0)
            
            // Content
            content
        }
    }
}

// MARK: - Liquid Glass Tab Indicator
struct LiquidGlassTabIndicator: View {
    let isSelected: Bool
    @State private var morphScale: CGFloat = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Material.ultraThinMaterial))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .scaleEffect(morphScale)
            .onChange(of: isSelected) { _, selected in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    morphScale = selected ? 1.05 : 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        morphScale = 1.0
                    }
                }
            }
    }
}

// MARK: - Animated Liquid Background
struct AnimatedLiquidGlass: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var scheme
    let intensity: CGFloat
    
    init(intensity: CGFloat = 1.0) {
        self.intensity = intensity
    }
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let colors = scheme == .dark ? darkColors : lightColors
                let time = phase
                
                for i in 0..<3 {
                    let offset = CGFloat(i) * 2.0
                    let x = size.width * (0.5 + 0.3 * sin(time + offset))
                    let y = size.height * (0.5 + 0.3 * cos(time * 0.7 + offset))
                    
                    let path = Path(ellipseIn: CGRect(
                        x: x - size.width * 0.3,
                        y: y - size.height * 0.3,
                        width: size.width * 0.6,
                        height: size.height * 0.6
                    ))
                    
                    context.drawLayer { ctx in
                        ctx.addFilter(.blur(radius: 40))
                        ctx.fill(path, with: .color(colors[i].opacity(0.3 * intensity)))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    private var darkColors: [Color] {
        [
            Color(hue: 0.6, saturation: 0.8, brightness: 0.7),
            Color(hue: 0.7, saturation: 0.7, brightness: 0.8),
            Color(hue: 0.55, saturation: 0.75, brightness: 0.75)
        ]
    }
    
    private var lightColors: [Color] {
        [
            Color(hue: 0.15, saturation: 0.5, brightness: 1.0),
            Color(hue: 0.1, saturation: 0.4, brightness: 0.95),
            Color(hue: 0.2, saturation: 0.45, brightness: 0.98)
        ]
    }
}

// MARK: - Liquid Glass Sheet Modifier
struct LiquidGlassSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let content: SheetContent
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                self.content
                    .presentationBackground(Material.ultraThinMaterial)
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func liquidGlassSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(LiquidGlassSheet(isPresented: isPresented, content: content()))
    }
}

// MARK: - Morphing Toggle Style
struct LiquidGlassToggleStyle: ToggleStyle {
    @State private var morphScale: CGFloat = 1.0
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(configuration.isOn ? Color.accentColor : Color.gray.opacity(0.3))
                .overlay {
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 15 : -15)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                }
                .frame(width: 51, height: 31)
                .liquidGlass(.subtle, cornerRadius: 16)
                .scaleEffect(morphScale)
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        morphScale = 0.95
                    }
                    configuration.isOn.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            morphScale = 1.0
                        }
                    }
                }
        }
    }
}

extension ToggleStyle where Self == LiquidGlassToggleStyle {
    static var liquidGlass: LiquidGlassToggleStyle {
        LiquidGlassToggleStyle()
    }
}