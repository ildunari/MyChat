import SwiftUI
import SwiftMath

struct InlineMathView: View {
    var latex: String
    @State private var renderingFailed = false
    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        mathContent
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(InlineMathContainer())
    }

    @ViewBuilder
    private var mathContent: some View {
        if renderingFailed {
            Text(latex)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(tokens.textSecondary)
                .frame(minHeight: 22)
        } else {
            SwiftMathLabel(latex: latex,
                            displayMode: false,
                            colorScheme: colorScheme,
                            renderingFailed: $renderingFailed)
        }
    }
}

struct BlockMathView: View {
    var latex: String
    @State private var renderingFailed = false
    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if renderingFailed {
                Text(latex)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(tokens.textSecondary)
                    .frame(minHeight: 44)
            } else {
                SwiftMathLabel(latex: latex,
                                displayMode: true,
                                colorScheme: colorScheme,
                                renderingFailed: $renderingFailed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(BlockMathContainer())
        .accessibilityElement(children: .contain)
    }
}

private struct InlineMathContainer: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: tokens.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.radiusSmall, style: .continuous)
                        .stroke(tokens.borderSoft.opacity(0.5), lineWidth: 0.4)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: tokens.radiusSmall, style: .continuous)
                        .fill(tokens.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.radiusSmall, style: .continuous)
                        .stroke(tokens.borderSoft, lineWidth: 0.5)
                )
        }
    }
}

private struct BlockMathContainer: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                        .stroke(tokens.borderSoft.opacity(0.5), lineWidth: 0.5)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                        .fill(tokens.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.radiusMedium, style: .continuous)
                        .stroke(tokens.borderSoft, lineWidth: 0.6)
                )
        }
    }
}

private struct SwiftMathLabel: UIViewRepresentable {
    let latex: String
    let displayMode: Bool
    let colorScheme: ColorScheme
    @Binding var renderingFailed: Bool

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.labelMode = displayMode ? .display : .text
        label.textAlignment = displayMode ? .center : .left
        label.fontSize = displayMode ? 21 : 17
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.labelMode = displayMode ? .display : .text
        uiView.textAlignment = displayMode ? .center : .left
        uiView.latex = latex
        uiView.textColor = colorScheme == .dark ? .white : .black
        uiView.sizeToFit()
        if uiView.error != nil {
            renderingFailed = true
        }
    }
}
